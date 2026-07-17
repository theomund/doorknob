/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:os"

get_token :: proc() -> (token: string, err: Error) {
	token = os.get_env("DISCORD_TOKEN", context.allocator)
	if token == "" {
		return token, .Env_Var_Not_Found
	}

	return token, nil
}
