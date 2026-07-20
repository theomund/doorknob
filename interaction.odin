/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:encoding/json"
import "core:strings"

new_response :: proc(content: string) -> Response {
	return {type = 4, data = {content = content}}
}

respond :: proc(response: Response, id: string, token: string) -> (rest: ^REST, err: Error) {
	combined := strings.concatenate({"/interactions/", id, "/", token, "/callback"}) or_return
	defer delete(combined)

	data := json.marshal(response) or_return

	return new_rest(combined, string(data))
}
