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

import gleam/dynamic/decode
import gleam/json

pub type Data {
  Data(heartbeat_interval: Int)
}

pub type Event {
  Event(op: Int, d: Data)
}

pub fn from_string(encoded: String) -> Event {
  let decoder = {
    use op <- decode.field("op", decode.int)
    use heartbeat_interval <- decode.subfield(
      ["d", "heartbeat_interval"],
      decode.int,
    )
    decode.success(Event(op:, d: Data(heartbeat_interval:)))
  }

  let assert Ok(event) = json.parse(from: encoded, using: decoder)

  event
}

pub fn heartbeat_interval(event: Event) -> Int {
  event.d.heartbeat_interval
}
