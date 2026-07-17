/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import curl "vendor:curl"

run :: proc() -> Error {
	curl.global_init(curl.GLOBAL_ALL) or_return
	defer curl.global_cleanup()

	return start_gateway()
}
