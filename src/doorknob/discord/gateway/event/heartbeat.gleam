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

import gleam/int
import gleam/json
import gleam/string
import logging.{Error as Err, Info}
import stratus

pub type Event {
  Event(op: Int, d: Int)
}

pub fn new(state: Int) -> Event {
  Event(1, state)
}

pub fn to_string(event: Event) -> String {
  json.to_string(
    json.object([#("op", json.int(event.op)), #("d", json.int(event.d))]),
  )
}

pub fn send(event: Event, conn: stratus.Connection, count: Int) -> Nil {
  let response = to_string(event) |> stratus.send_text_message(conn, _)

  let attempt = int.to_string(count)

  case response {
    Ok(_) ->
      logging.log(
        Info,
        "Heartbeat event #"
          <> attempt
          <> " was successfully sent: "
          <> string.inspect(event),
      )
    Error(_) ->
      logging.log(
        Err,
        "Heartbeat event #"
          <> attempt
          <> " was unsuccessfully sent: "
          <> string.inspect(event),
      )
  }
}
