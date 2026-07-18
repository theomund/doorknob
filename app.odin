/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:container/queue"
import curl "vendor:curl"

run :: proc() -> Error {
	curl.global_init(curl.GLOBAL_ALL) or_return
	defer curl.global_cleanup()

	multi := new_multi() or_return
	defer curl.multi_cleanup(multi)

	gateway := new_gateway(multi) or_return
	defer destroy_gateway(gateway)

	curl.multi_add_handle(multi, gateway.handle) or_return
	defer curl.multi_remove_handle(multi, gateway.handle)

	for running: i32 = -1; running != 0; {
		curl.multi_perform(multi, &running) or_return
		curl.multi_poll(multi, nil, 0, 1000, nil) or_return

		for rest, ok := queue.pop_front_safe(&gateway.rests); ok; {
			curl.multi_add_handle(multi, rest.handle) or_return
			defer curl.multi_remove_handle(multi, rest.handle)
		}
	}

	return nil
}
