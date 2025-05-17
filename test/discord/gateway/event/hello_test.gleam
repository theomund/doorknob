// Doorknob - Artificial intelligence companion written in Gleam.
// Copyright (C) 2025 Theomund
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import doorknob/discord/gateway/event/hello
import gleeunit/should

pub fn from_string_test() -> Nil {
  let encoded =
    "{\"t\":null,\"s\":null,\"op\":10,\"d\":{\"heartbeat_interval\":41250,\"_trace\":[\"[\\\"gateway-prd-us-east1-c-n2nk\\\",{\\\"micros\\\":0.0}]\"]}}"

  let actual = hello.from_string(encoded)

  let data = hello.Data(heartbeat_interval: 41_250)
  let expected = hello.Event(op: 10, d: data)

  actual |> should.equal(expected)
}
