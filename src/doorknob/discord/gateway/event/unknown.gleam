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
import gleam/option.{type Option, None}

pub type UnknownEvent {
  UnknownEvent(op: Int, s: Option(Int), t: Option(String))
}

pub fn from_string(encoded: String) -> UnknownEvent {
  let decoder = {
    use op <- decode.field("op", decode.int)
    use s <- decode.optional_field("s", None, decode.optional(decode.int))
    use t <- decode.optional_field("t", None, decode.optional(decode.string))
    decode.success(UnknownEvent(op:, s:, t:))
  }

  let assert Ok(event) = json.parse(from: encoded, using: decoder)

  event
}

pub fn sequence(event: UnknownEvent) -> Option(Int) {
  event.s
}

pub fn opcode(event: UnknownEvent) -> Int {
  event.op
}
