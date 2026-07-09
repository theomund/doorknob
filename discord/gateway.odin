package discord

import "base:runtime"
import "core:container/queue"
import "core:encoding/json"
import "core:log"
import curl "vendor:curl"

GATEWAY_URL :: "wss://gateway.discord.gg/?v=10&encoding=json"

Error :: union {
	curl.code,
	json.Marshal_Error,
	runtime.Allocator_Error,
}

Gateway :: struct {
	ctx:      runtime.Context,
	err:      Error,
	events:   queue.Queue(Event),
	frame:    []byte,
	handle:   ^curl.CURL,
	paused:   bool,
	sent:     uint,
	sequence: uint,
}

read_callback :: proc "c" (buffer: [^]u8, size: uint, nitems: uint, instream: rawptr) -> uint {
	gateway := cast(^Gateway)instream
	context = gateway.ctx

	if gateway.sent == 0 {
		if gateway.events.len == 0 {
			gateway.paused = true
			return curl.READFUNC_PAUSE
		}

		event := queue.pop_front(&gateway.events)
		gateway.frame, gateway.err = json.marshal(event)

		if curl.ws_start_frame(
			   gateway.handle,
			   u32(curl.WS_TEXT),
			   curl.off_t(len(gateway.frame)),
		   ) !=
		   .E_OK {
			return curl.READFUNC_ABORT
		}
	}

	n := min(size * nitems, uint(len(gateway.frame)) - gateway.sent)

	copy(buffer[:n], gateway.frame[gateway.sent:gateway.sent + n])

	gateway.sent += n

	return n
}

write_callback :: proc "c" (buffer: [^]u8, size: uint, nitems: uint, outstream: rawptr) -> uint {
	gateway := cast(^Gateway)outstream
	context = gateway.ctx

	meta := curl.ws_meta(gateway.handle)
	n := size * nitems

	switch meta.flags {
	case curl.WS_TEXT:
		frame := buffer[:n]
		log.info("Received 'TEXT' frame:", string(frame))

		event: Event
		json.unmarshal(frame, &event)
		log.infof("Received '%v' gateway event: %v", event.op, event)

		if event.s != nil do gateway.sequence = event.s.?

		enqueue(gateway, Event{op = .Heartbeat, d = gateway.sequence})
	case curl.WS_CLOSE:
		log.warn("Received 'CLOSE' frame")
	case:
		log.warn("Received 'UNKNOWN' frame")
	}

	return n
}

enqueue :: proc(gateway: ^Gateway, event: Event) -> Error {
	queue.push(&gateway.events, event) or_return

	if gateway.paused == true {
		curl.easy_pause(gateway.handle, curl.PAUSE_SEND_CONT) or_return
		gateway.paused = false
	}

	return nil
}

run :: proc() -> Error {
	curl.global_init(curl.GLOBAL_ALL) or_return
	defer curl.global_cleanup()

	handle := curl.easy_init()
	if handle == nil do return .E_FAILED_INIT
	defer curl.easy_cleanup(handle)

	gateway := Gateway {
		ctx    = context,
		handle = handle,
	}

	curl.easy_setopt(handle, .READDATA, &gateway) or_return
	curl.easy_setopt(handle, .WRITEDATA, &gateway) or_return
	curl.easy_setopt(handle, .READFUNCTION, read_callback) or_return
	curl.easy_setopt(handle, .WRITEFUNCTION, write_callback) or_return
	curl.easy_setopt(handle, .URL, GATEWAY_URL) or_return
	curl.easy_setopt(handle, .UPLOAD, 1) or_return

	curl.easy_perform(handle) or_return

	return nil
}
