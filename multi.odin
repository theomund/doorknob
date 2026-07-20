/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import curl "vendor:curl"

new_multi :: proc() -> (^curl.CURLM, Error) {
	multi := curl.multi_init()

	return multi, multi == nil ? .BAD_HANDLE : nil
}

destroy_multi :: proc(multi: ^curl.CURLM) {
	curl.multi_cleanup(multi)
}
