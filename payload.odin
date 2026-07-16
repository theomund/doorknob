/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "core:encoding/json"

Hello :: struct {
	heartbeat_interval: uint,
}

Identify :: struct {
	token:      string,
	intents:    uint,
	properties: struct {
		os, browser, device: string,
	},
}

Operation :: enum {
	Dispatch      = 0,
	Heartbeat     = 1,
	Identify      = 2,
	Hello         = 10,
	Heartbeat_Ack = 11,
}

Event :: struct {
	op: Operation,
	d:  json.Value,
	s:  Maybe(uint),
	t:  Maybe(string),
}

to_value :: proc(raw: $T) -> (value: json.Value, err: Error) {
	bytes := json.marshal(raw) or_return
	value = json.parse(data = bytes, parse_integers = true) or_return

	return value, nil
}

heartbeat :: proc(sequence: uint) -> (event: Event, err: Error) {
	value := to_value(sequence) or_return

	return Event{op = .Heartbeat, d = value}, nil
}

identify :: proc(token: string) -> (event: Event, err: Error) {
	data := Identify {
		token = token,
		intents = INTENTS,
		properties = {os = ODIN_OS_STRING, browser = NAME, device = NAME},
	}

	value := to_value(data) or_return

	return Event{op = .Identify, d = value}, nil
}
