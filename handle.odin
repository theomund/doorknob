/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import curl "vendor:curl"

new_handle :: proc() -> (handle: ^curl.CURL, err: Error) {
	handle = curl.easy_init()
	if handle == nil {
		return handle, .E_FAILED_INIT
	}

	return handle, nil
}

set_options :: proc(handle: ^curl.CURL, options: map[curl.option]any) -> Error {
	for key, value in options {
		curl.easy_setopt(handle, key, value) or_return
	}

	return nil
}
