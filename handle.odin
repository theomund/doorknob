/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:log"
import curl "vendor:curl"

new_handle :: proc() -> (handle: ^curl.CURL, err: Error) {
	handle = curl.easy_init()
	if handle == nil {
		return handle, .E_FAILED_INIT
	}

	return handle, nil
}

set_options :: proc(handle: ^curl.CURL, options: map[curl.option]Value) -> Error {
	for key, value in options {
		switch v in value {
		case cstring, curl.write_callback, curl.xferinfo_callback, i64, rawptr:
			curl.easy_setopt(handle, key, v) or_return
			log.debug("Assigned option", key, "with value:", v)
		case:
			return .E_SETOPT_OPTION_SYNTAX
		}
	}

	return nil
}
