/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "base:runtime"
import "core:fmt"
import "core:mem"

new_tracker :: proc() -> Tracker {
	allocator := new(mem.Tracking_Allocator)
	ctx := runtime.default_context()

	mem.tracking_allocator_init(allocator, ctx.allocator)

	ctx.allocator = mem.tracking_allocator(allocator)

	return {allocator, ctx}
}

delete_tracker :: proc(tracker: Tracker) {
	if len(tracker.allocator.allocation_map) > 0 {
		fmt.eprintf("=== %v allocations not freed: ===\n", len(tracker.allocator.allocation_map))
		for _, entry in tracker.allocator.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}

	mem.tracking_allocator_destroy(tracker.allocator)
}
