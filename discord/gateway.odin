/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package discord

import "base:runtime"
import "core:container/queue"
import "core:encoding/json"
import "core:log"
import "core:time"
import curl "vendor:curl"

GATEWAY_URL :: "wss://gateway.discord.gg/?v=10&encoding=json"

Error :: union {
	curl.code,
	json.Marshal_Error,
	json.Unmarshal_Error,
	runtime.Allocator_Error,
}

Gateway :: struct {
	ctx:                runtime.Context,
	err:                Error,
	events:             queue.Queue(Event),
	handle:             ^curl.CURL,
	heartbeat_interval: time.Duration,
	inbound_frame:      [dynamic]byte,
	last_run:           time.Time,
	outbound_frame:     []byte,
	paused:             bool,
	sent:               uint,
	sequence:           uint,
}

read_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, instream: rawptr) -> uint {
	gateway := cast(^Gateway)instream
	context = gateway.ctx

	if gateway.sent == 0 {
		if gateway.events.len == 0 {
			gateway.paused = true
			return curl.READFUNC_PAUSE
		}

		event := queue.pop_front(&gateway.events)
		gateway.outbound_frame, gateway.err = json.marshal(event)

		if curl.ws_start_frame(
			   gateway.handle,
			   u32(curl.WS_TEXT),
			   curl.off_t(len(gateway.outbound_frame)),
		   ) !=
		   .E_OK {
			return curl.READFUNC_ABORT
		}
	}

	n := min(size * nitems, uint(len(gateway.outbound_frame)) - gateway.sent)

	copy(buffer[:n], gateway.outbound_frame[gateway.sent:gateway.sent + n])

	gateway.sent += n

	if gateway.sent == len(gateway.outbound_frame) {
		gateway.sent = 0
		destroy_outbound(gateway)
	}

	return n
}

write_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, outstream: rawptr) -> uint {
	gateway := cast(^Gateway)outstream
	context = gateway.ctx

	n := size * nitems

	meta := curl.ws_meta(gateway.handle)
	if meta == nil do return 0

	append(&gateway.inbound_frame, ..buffer[:n])

	if meta.bytesleft != 0 do return n

	switch meta.flags {
	case curl.WS_TEXT:
		log.info("Received text frame:", string(gateway.inbound_frame[:]))

		event: Event
		gateway.err = json.unmarshal(gateway.inbound_frame[:], &event)
		defer destroy_event(&event)

		log.info("Received gateway event:", event)

		if event.s != nil do gateway.sequence = event.s.?

		#partial switch event.op {
		case .Hello:
			hello := event.d.(Hello)
			gateway.heartbeat_interval = time.Duration(hello.heartbeat_interval) * time.Millisecond
		case .Heartbeat:
			gateway.err = enqueue(gateway, Event{op = .Heartbeat, d = gateway.sequence})
		}

	case curl.WS_CLOSE:
		log.warn("Received close frame")
	case:
		log.warn("Received unhandled frame")
	}

	destroy_inbound(gateway)

	return n
}

xferinfo_callback :: proc "c" (clientp: rawptr, dltotal, dlnow, ultotal, ulnow: i64) -> curl.code {
	gateway := cast(^Gateway)clientp
	context = gateway.ctx

	if gateway.heartbeat_interval == 0 do return .E_OK

	current_time := time.now()
	elapsed := time.diff(gateway.last_run, current_time)

	if (elapsed >= gateway.heartbeat_interval) {
		gateway.last_run = current_time
		gateway.err = enqueue(gateway, Event{op = .Heartbeat, d = gateway.sequence})
	}

	return .E_OK
}

enqueue :: proc(gateway: ^Gateway, event: Event) -> Error {
	queue.push(&gateway.events, event) or_return

	if gateway.paused == true {
		curl.easy_pause(gateway.handle, curl.PAUSE_SEND_CONT) or_return
		gateway.paused = false
	}

	return nil
}

destroy_event :: proc(event: ^Event) {
	if event.t != nil {
		delete(event.t.?)
		event.t = nil
	}
}

destroy_inbound :: proc(gateway: ^Gateway) {
	delete(gateway.inbound_frame)
	gateway.inbound_frame = nil
}

destroy_outbound :: proc(gateway: ^Gateway) {
	delete(gateway.outbound_frame)
	gateway.outbound_frame = nil
}

destroy_gateway :: proc(gateway: ^Gateway) {
	destroy_inbound(gateway)
	destroy_outbound(gateway)

	for event, ok := queue.pop_front_safe(&gateway.events); ok; do destroy_event(&event)

	queue.destroy(&gateway.events)
}

run :: proc() -> Error {
	curl.global_init(curl.GLOBAL_ALL) or_return
	defer curl.global_cleanup()

	handle := curl.easy_init()
	if handle == nil do return .E_FAILED_INIT
	defer curl.easy_cleanup(handle)

	gateway := Gateway {
		ctx      = context,
		handle   = handle,
		last_run = time.now(),
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

	if err := curl.easy_perform(handle); err != nil do return gateway.err != nil ? gateway.err : err

	return nil
}
