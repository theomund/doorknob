package discord

import "base:runtime"
import "core:log"
import curl "vendor:curl"

GATEWAY_URL :: "wss://gateway.discord.gg/?v=10&encoding=json"

Error :: union {
	curl.code,
}

Gateway :: struct {
	ctx:    runtime.Context,
	handle: ^curl.CURL,
}

read_callback :: proc "c" (buffer: [^]u8, size: uint, nitems: uint, instream: rawptr) -> uint {
	gateway := cast(^Gateway)instream
	context = gateway.ctx

	return 0
}

write_callback :: proc "c" (buffer: [^]u8, size: uint, nitems: uint, outstream: rawptr) -> uint {
	gateway := cast(^Gateway)outstream
	context = gateway.ctx

	n := size * nitems
	frame := string(buffer[:n])

	log.info("Received gateway frame:", frame)

	return n
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
