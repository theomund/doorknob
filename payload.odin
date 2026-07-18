/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:encoding/json"

destroy_event :: proc(event: ^Event) -> Error {
	json.destroy_value(event.d)

	if event.t != nil {
		delete(event.t.?) or_return
		event.t = nil
	}

	return nil
}

to_value :: proc(raw: $T) -> (value: json.Value, err: Error) {
	bytes := json.marshal(raw) or_return
	defer delete(bytes)

	value = json.parse(data = bytes, parse_integers = true) or_return

	return value, nil
}

new_heartbeat :: proc(sequence: uint) -> (event: Event, err: Error) {
	value := to_value(sequence) or_return

	return Event{op = .Heartbeat, d = value}, nil
}

new_identify :: proc(token: string) -> (event: Event, err: Error) {
	data := Identify {
		token = token,
		intents = INTENTS,
		properties = {os = ODIN_OS_STRING, browser = NAME, device = NAME},
	}

	value := to_value(data) or_return

	return Event{op = .Identify, d = value}, nil
}
