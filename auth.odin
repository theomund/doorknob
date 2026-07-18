/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:os"

get_env :: proc(key: string) -> (string, Error) {
	env := os.get_env(key, context.allocator)

	return env, env == "" ? .Env_Var_Not_Found : nil
}

get_app :: proc() -> (string, Error) {
	return get_env("DISCORD_APP")
}

get_guild :: proc() -> (string, Error) {
	return get_env("DISCORD_GUILD")
}

get_token :: proc() -> (string, Error) {
	return get_env("DISCORD_TOKEN")
}
