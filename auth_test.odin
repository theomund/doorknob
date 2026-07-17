/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:os"
import "core:testing"

@(test)
test_get_token :: proc(t: ^testing.T) {
	os.set_env("DISCORD_TOKEN", "foo")

	token, err := get_token()
	if err != nil {
		testing.fail(t)
	}
	defer delete(token)

	testing.expect_value(t, token, "foo")
}
