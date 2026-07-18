/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:encoding/json"
import "core:strings"

new_command :: proc(name, description: string) -> Command {
	return {name = name, description = description, type = 1}
}

register_command :: proc(command: Command) -> (rest: ^REST, err: Error) {
	app := get_app() or_return
	guild := get_guild() or_return

	endpoint := strings.concatenate(
		{"/applications/", app, "/guilds/", guild, "/commands"},
	) or_return

	data := json.marshal(command) or_return

	return new_rest(endpoint, data)
}
