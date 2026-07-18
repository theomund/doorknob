/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:os"
import "core:testing"

@(test)
test_get_app :: proc(t: ^testing.T) {
	os.set_env("DISCORD_APP", "1234")

	app, err := get_app()
	if err != nil {
		testing.fail(t)
	}
	defer delete(app)

	testing.expect_value(t, app, "1234")
}

@(test)
test_get_guild :: proc(t: ^testing.T) {
	os.set_env("DISCORD_GUILD", "4567")

	guild, err := get_guild()
	if err != nil {
		testing.fail(t)
	}
	defer delete(guild)

	testing.expect_value(t, guild, "4567")
}

@(test)
test_get_token :: proc(t: ^testing.T) {
	os.set_env("DISCORD_TOKEN", "hunter2")

	token, err := get_token()
	if err != nil {
		testing.fail(t)
	}
	defer delete(token)

	testing.expect_value(t, token, "hunter2")
}
