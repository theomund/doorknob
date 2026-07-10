/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package discord

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

Data :: union {
	Hello,
	Identify,
	uint,
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
	d:  Data,
	s:  Maybe(uint),
	t:  Maybe(string),
}

heartbeat :: proc(sequence: uint) -> Event {
	return Event{op = .Heartbeat, d = sequence}
}

identify :: proc(token: string) -> Event {
	return Event {
		op = .Identify,
		d = Identify {
			token = token,
			intents = INTENTS,
			properties = {os = ODIN_OS_STRING, browser = NAME, device = NAME},
		},
	}
}
