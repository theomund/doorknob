/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package discord

Hello :: struct {
	heartbeat_interval: uint,
}

Data :: union {
	Hello,
	uint,
}

Operation :: enum {
	Heartbeat     = 1,
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
