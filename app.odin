/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:container/queue"
import "core:log"
import "core:sync"
import curl "vendor:curl"

run :: proc() -> Error {
	register_interrupt()

	curl.global_init(curl.GLOBAL_ALL) or_return
	defer curl.global_cleanup()

	multi := new_multi() or_return
	defer curl.multi_cleanup(multi)

	gateway := new_gateway() or_return
	defer destroy_gateway(gateway)

	curl.multi_add_handle(multi, gateway.handle) or_return

	running: i32

	for !sync.atomic_load(&interrupted) {
		curl.multi_perform(multi, &running) or_return

		if running == 0 {
			break
		}

		if rest, ok := queue.pop_front_safe(&gateway.rests); ok {
			curl.multi_add_handle(multi, rest.handle) or_return
		}

		curl.multi_poll(multi, nil, 0, 1000, nil) or_return
	}

	log.warn("Received interrupt signal; shutting down program")

	return nil
}
