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

new_rest :: proc(endpoint: string, data: string) -> (rest: ^REST, err: Error) {
	rest = new(REST) or_return
	rest^ = {
		ctx    = context,
		data   = strings.clone_to_cstring(data),
		handle = new_handle() or_return,
	}

	options := make(map[curl.option]Value)
	defer delete(options)

	token := get_token() or_return
	defer delete(token)

	authorization := combine_strings({"Authorization: Bot ", token}) or_return
	defer delete(authorization)

	url := combine_strings({REST_URL, endpoint}) or_return
	defer delete(url)

	options[.HTTPHEADER] = set_headers({authorization, "Content-Type: application/json"})
	options[.URL] = url
	options[.WRITEDATA] = rest
	options[.WRITEFUNCTION] = rest_write_callback

	if data != "" {
		options[.POSTFIELDS] = rest.data
		delete(data)
	}

	set_options(rest.handle, options) or_return

	return rest, nil
}

set_headers :: proc(headers: []cstring) -> (chunk: ^curl.slist) {
	for header in headers {
		chunk = curl.slist_append(chunk, header)
	}

	return chunk
}

combine_strings :: proc(pieces: []string) -> (result: cstring, err: Error) {
	combined := strings.concatenate(pieces) or_return
	defer delete(combined)

	clone := strings.clone_to_cstring(combined) or_return

	return clone, nil
}

destroy_rest :: proc(rest: ^REST) {
	curl.easy_cleanup(rest.handle)

	delete(rest.data)
	free(rest)
}
