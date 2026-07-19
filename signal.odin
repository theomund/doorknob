/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:sync"
import "core:sys/posix"

interrupted: bool

handle_interrupt :: proc "c" (signal: posix.Signal) {
	sync.atomic_store(&interrupted, true)
}

register_interrupt :: proc() {
	posix.signal(.SIGINT, handle_interrupt)
}
