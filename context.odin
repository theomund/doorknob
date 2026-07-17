/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "base:runtime"
import "core:log"

new_context :: proc() -> runtime.Context {
	ctx := runtime.default_context()
	ctx.logger = log.create_console_logger()

	return ctx
}

destroy_context :: proc(ctx: runtime.Context) {
	log.destroy_console_logger(ctx.logger)
}
