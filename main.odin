/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:log"
import "core:os"

main :: proc() {
	context = new_context()
	defer destroy_context(context)

	if err := run(); err != nil {
		log.error("Encountered error:", err)
		os.exit(1)
	}
}
