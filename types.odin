/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 */

package main

import "base:runtime"
import "core:container/queue"
import "core:encoding/json"
import "core:os"
import "core:time"
import curl "vendor:curl"

Error :: union {
	curl.code,
	curl.Mcode,
	json.Error,
	json.Marshal_Error,
	json.Unmarshal_Error,
	os.General_Error,
	runtime.Allocator_Error,
}

Event :: struct {
	op: Operation,
	d:  json.Value,
	s:  Maybe(uint),
	t:  Maybe(string),
}

Gateway :: struct {
	ctx:                runtime.Context,
	err:                Error,
	events:             queue.Queue(Event),
	handle:             ^curl.CURL,
	heartbeat_interval: time.Duration,
	inbound_frame:      [dynamic]byte,
	last_run:           time.Time,
	outbound_frame:     []byte,
	paused:             bool,
	sent:               uint,
	sequence:           uint,
	token:              string,
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

REST :: struct {
	ctx:    runtime.Context,
	err:    Error,
	handle: ^curl.CURL,
	token:  string,
}

Value :: union {
	cstring,
	curl.write_callback,
	curl.xferinfo_callback,
	i64,
	rawptr,
}
