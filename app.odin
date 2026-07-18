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

	multi := curl.multi_init()
	if multi == nil {
		return .E_FAILED_INIT
	}
	defer curl.multi_cleanup(multi)

	gateway := new_gateway() or_return
	defer destroy_gateway(gateway)

	curl.multi_add_handle(multi, gateway.handle) or_return
	defer curl.multi_remove_handle(multi, gateway.handle)

	rest := new_rest("/gateway") or_return
	defer destroy_rest(rest)

	curl.multi_add_handle(multi, rest.handle) or_return
	defer curl.multi_remove_handle(multi, rest.handle)

	for running: i32 = -1; running != 0; {
		if err := curl.multi_perform(multi, &running); err != nil {
			if gateway.err != nil {
				return gateway.err
			} else if rest.err != nil {
				return rest.err
			} else {
				return err
			}
		}

		curl.multi_poll(multi, nil, 0, 1000, nil) or_return
	}

	return nil
}
