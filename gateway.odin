/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:container/queue"
import "core:encoding/json"
import "core:log"
import "core:time"
import curl "vendor:curl"

new_gateway :: proc() -> (gateway: ^Gateway, err: Error) {
	gateway = new(Gateway) or_return
	gateway^ = Gateway {
		ctx      = context,
		handle   = new_handle() or_return,
		last_run = time.now(),
		token    = get_token() or_return,
	}

	options := make(map[curl.option]Value)
	defer delete(options)

	options[.NOPROGRESS] = 0
	options[.READDATA] = gateway
	options[.READFUNCTION] = gateway_read_callback
	options[.UPLOAD] = 1
	options[.URL] = GATEWAY_URL
	options[.WRITEDATA] = gateway
	options[.WRITEFUNCTION] = gateway_write_callback
	options[.XFERINFODATA] = gateway
	options[.XFERINFOFUNCTION] = gateway_xferinfo_callback

	set_options(gateway.handle, options) or_return

	return gateway, nil
}

gateway_read_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, instream: rawptr) -> uint {
	gateway := cast(^Gateway)instream
	context = gateway.ctx

	n := size * nitems

	if gateway.err = gateway_read_helper(buffer, n, gateway); gateway.err != nil {
		return gateway.paused ? curl.READFUNC_PAUSE : curl.READFUNC_ABORT
	}

	return n
}

gateway_read_helper :: proc(buffer: [^]u8, count: uint, gateway: ^Gateway) -> Error {
	if gateway.sent == 0 {
		event, ok := queue.pop_front_safe(&gateway.events)
		if !ok {
			gateway.paused = true
			return .E_GOT_NOTHING
		}

		gateway.outbound_frame = json.marshal(event) or_return

		curl.ws_start_frame(
			gateway.handle,
			u32(curl.WS_TEXT),
			curl.off_t(len(gateway.outbound_frame)),
		) or_return
	}

	n := min(count, uint(len(gateway.outbound_frame)) - gateway.sent)

	copy(buffer[:n], gateway.outbound_frame[gateway.sent:gateway.sent + n])

	gateway.sent += n

	if gateway.sent == len(gateway.outbound_frame) {
		log.debug("Sent text frame:", string(gateway.outbound_frame))
		gateway.sent = 0
		destroy_outbound(gateway) or_return
	}

	return nil
}

gateway_write_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, outstream: rawptr) -> uint {
	gateway := cast(^Gateway)outstream
	context = gateway.ctx

	n := size * nitems

	gateway.err = gateway_write_helper(buffer, n, gateway)

	return gateway.err != nil ? 0 : n
}

gateway_write_helper :: proc(buffer: [^]u8, n: uint, gateway: ^Gateway) -> Error {
	meta := curl.ws_meta(gateway.handle)
	if meta == nil {
		return .E_GOT_NOTHING
	}

	append(&gateway.inbound_frame, ..buffer[:n]) or_return

	if meta.bytesleft != 0 {
		return nil
	}

	switch meta.flags {
	case curl.WS_TEXT:
		frame := gateway.inbound_frame[:]
		log.debug("Received text frame:", string(frame))

		event: Event
		json.unmarshal(frame, &event) or_return
		defer destroy_event(&event)

		handle_event(gateway, event) or_return
	case curl.WS_CLOSE:
		log.warn("Received close frame")
	case:
		log.warn("Received unhandled frame")
	}

	return destroy_inbound(gateway)
}

gateway_xferinfo_callback :: proc "c" (
	clientp: rawptr,
	dltotal, dlnow, ultotal, ulnow: i64,
) -> i32 {
	gateway := cast(^Gateway)clientp
	context = gateway.ctx

	gateway.err = gateway_xferinfo_helper(gateway)

	return gateway.err != nil ? i32(curl.code.E_ABORTED_BY_CALLBACK) : i32(curl.code.E_OK)
}

gateway_xferinfo_helper :: proc(gateway: ^Gateway) -> Error {
	if gateway.heartbeat_interval != 0 {
		current_time := time.now()
		elapsed := time.diff(gateway.last_run, current_time)

		if (elapsed >= gateway.heartbeat_interval) {
			gateway.last_run = current_time

			heartbeat := new_heartbeat(gateway.sequence) or_return
			enqueue(gateway, heartbeat) or_return
		}
	}

	return nil
}

enqueue :: proc(gateway: ^Gateway, event: Event) -> Error {
	queue.push(&gateway.events, event) or_return

	if gateway.paused == true {
		curl.easy_pause(gateway.handle, curl.PAUSE_SEND_CONT) or_return
		gateway.paused = false
	}

	return nil
}

handle_event :: proc(gateway: ^Gateway, event: Event) -> Error {
	log.debug("Received gateway event:", event)

	if event.s != nil {
		gateway.sequence = event.s.?
	}

	#partial switch event.op {
	case .Dispatch:
		switch type := event.t.?; type {
		case "INTERACTION_CREATE":
			d := event.d.(json.Object)

			command := d["data"].(json.Object)["name"].(json.String)
			log.debug("Received interactive command:", command)

			id := d["id"].(json.String)
			token := d["token"].(json.String)
			response := new_response("Pong!")
			rest := respond(response, id, token) or_return

			queue.push_back(&gateway.rests, rest) or_return
		case "READY":
			ping := new_command("ping", "Responds with a pong message.")
			rest := register_command(ping) or_return

			queue.push_back(&gateway.rests, rest) or_return
		case:
			log.warn("Received unhandled dispatch type:", type)
		}
	case .Hello:
		d := event.d.(json.Object)

		heartbeat_interval := d["heartbeat_interval"].(json.Integer)
		gateway.heartbeat_interval = time.Duration(heartbeat_interval) * time.Millisecond

		identify := new_identify(gateway.token) or_return
		enqueue(gateway, identify) or_return
	case .Heartbeat:
		heartbeat := new_heartbeat(gateway.sequence) or_return
		enqueue(gateway, heartbeat) or_return
	}

	return nil
}

destroy_inbound :: proc(gateway: ^Gateway) -> Error {
	delete(gateway.inbound_frame) or_return
	gateway.inbound_frame = nil

	return nil
}

destroy_outbound :: proc(gateway: ^Gateway) -> Error {
	delete(gateway.outbound_frame) or_return
	gateway.outbound_frame = nil

	return nil
}

destroy_gateway :: proc(gateway: ^Gateway) -> Error {
	destroy_inbound(gateway) or_return
	destroy_outbound(gateway) or_return

	for event, ok := queue.pop_front_safe(&gateway.events); ok; {
		destroy_event(&event) or_return
	}

	queue.destroy(&gateway.events)
	curl.easy_cleanup(gateway.handle)

	delete(gateway.token)
	free(gateway)

	return nil
}
