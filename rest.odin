/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import curl "vendor:curl"

new_rest :: proc() -> (rest: REST, err: Error) {
	rest = REST {
		ctx    = context,
		handle = new_handle() or_return,
		token  = get_token() or_return,
	}

	options := make(map[curl.option]Value)
	defer delete(options)

	options[.URL] = REST_URL

	return rest, nil
}

destroy_rest :: proc(rest: REST) {
	delete(rest.token)

	curl.easy_cleanup(rest.handle)
}
