/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:log"
import "core:strings"
import curl "vendor:curl"

rest_write_callback :: proc "c" (buffer: [^]u8, size, nitems: uint, outstream: rawptr) -> uint {
	rest := cast(^REST)outstream
	context = rest.ctx

	n := size * nitems

	rest.err = rest_write_helper(buffer, n, rest)

	return rest.err != nil ? 0 : n
}

rest_write_helper :: proc(buffer: [^]u8, n: uint, rest: ^REST) -> Error {
	response := string(buffer[:n])

	log.debug("Received REST response:", response)

	return nil
}

new_rest :: proc(endpoint: string) -> (rest: ^REST, err: Error) {
	rest = new(REST)
	rest^ = {
		ctx    = context,
		handle = new_handle() or_return,
		token  = get_token() or_return,
	}

	options := make(map[curl.option]Value)
	defer delete(options)

	absolute := strings.concatenate({REST_URL, endpoint}) or_return
	url := strings.clone_to_cstring(absolute) or_return

	options[.URL] = url
	options[.WRITEDATA] = rest
	options[.WRITEFUNCTION] = rest_write_callback

	set_options(rest.handle, options) or_return

	return rest, nil
}

destroy_rest :: proc(rest: ^REST) {
	delete(rest.token)

	curl.easy_cleanup(rest.handle)
}
