/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:container/queue"
import "core:encoding/json"
import "core:log"
import "core:os"
import "core:time"
import curl "vendor:curl"

read_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, instream: rawptr) -> uint {
	gateway := cast(^Gateway)instream
	context = gateway.ctx

	n := size * nitems

	if gateway.err = read_helper(buffer, n, gateway); gateway.err != nil {
		return gateway.paused ? curl.READFUNC_PAUSE : curl.READFUNC_ABORT
	}

	return n
}

read_helper :: proc(buffer: [^]u8, count: uint, gateway: ^Gateway) -> Error {
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

write_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, outstream: rawptr) -> uint {
	gateway := cast(^Gateway)outstream
	context = gateway.ctx

	n := size * nitems

	if gateway.err = write_helper(buffer, n, gateway); gateway.err != nil {
		return 0
	}

	return n
}

write_helper :: proc(buffer: [^]u8, n: uint, gateway: ^Gateway) -> Error {
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

xferinfo_callback :: proc "c" (clientp: rawptr, dltotal, dlnow, ultotal, ulnow: i64) -> curl.code {
	gateway := cast(^Gateway)clientp
	context = gateway.ctx

	if gateway.err = xferinfo_helper(gateway); gateway.err != nil {
		return .E_ABORTED_BY_CALLBACK
	}

	return .E_OK
}

xferinfo_helper :: proc(gateway: ^Gateway) -> Error {
	if gateway.heartbeat_interval != 0 {
		current_time := time.now()
		elapsed := time.diff(gateway.last_run, current_time)

		if (elapsed >= gateway.heartbeat_interval) {
			gateway.last_run = current_time

			heartbeat_event := heartbeat(gateway.sequence) or_return
			enqueue(gateway, heartbeat_event) or_return
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
	log.info("Received gateway event:", event)

	if event.s != nil {
		gateway.sequence = event.s.?
	}

	#partial switch event.op {
	case .Hello:
		heartbeat_interval := event.d.(json.Object)["heartbeat_interval"].(json.Integer)
		gateway.heartbeat_interval = time.Duration(heartbeat_interval) * time.Millisecond

		identify_event := identify(gateway.token) or_return
		enqueue(gateway, identify_event) or_return
	case .Heartbeat:
		heartbeat_event := heartbeat(gateway.sequence) or_return
		enqueue(gateway, heartbeat_event) or_return
	}

	return nil
}

destroy_event :: proc(event: ^Event) -> Error {
	if event.t != nil {
		delete(event.t.?) or_return
		event.t = nil
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

	return nil
}

start_gateway :: proc() -> Error {
	curl.global_init(curl.GLOBAL_ALL) or_return
	defer curl.global_cleanup()

	handle := curl.easy_init()
	if handle == nil {
		return .E_FAILED_INIT
	}
	defer curl.easy_cleanup(handle)

	token := os.get_env("DISCORD_TOKEN", context.allocator)
	if token == "" {
		return .Env_Var_Not_Found
	}
	defer delete(token)

	gateway := Gateway {
		ctx      = context,
		handle   = handle,
		last_run = time.now(),
		token    = token,
	}
	defer destroy_gateway(&gateway)

	curl.easy_setopt(handle, .NOPROGRESS, 0) or_return
	curl.easy_setopt(handle, .READDATA, &gateway) or_return
	curl.easy_setopt(handle, .READFUNCTION, read_callback) or_return
	curl.easy_setopt(handle, .UPLOAD, 1) or_return
	curl.easy_setopt(handle, .URL, GATEWAY_URL) or_return
	curl.easy_setopt(handle, .WRITEDATA, &gateway) or_return
	curl.easy_setopt(handle, .WRITEFUNCTION, write_callback) or_return
	curl.easy_setopt(handle, .XFERINFODATA, &gateway) or_return
	curl.easy_setopt(handle, .XFERINFOFUNCTION, xferinfo_callback) or_return

	if err := curl.easy_perform(handle); err != nil {
		return gateway.err != nil ? gateway.err : err
	}

	return nil
}
