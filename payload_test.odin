/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:encoding/json"
import "core:testing"

@(test)
test_new_heartbeat :: proc(t: ^testing.T) {
	heartbeat, err := new_heartbeat(1)
	if err != nil {
		testing.fail(t)
	}

	testing.expect_value(t, heartbeat.op, Operation.Heartbeat)
	testing.expect_value(t, heartbeat.d.(json.Integer), 1)
}
