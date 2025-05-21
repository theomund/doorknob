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

import gleam/json
import gleam/string
import logging.{Error as Err, Info}
import stratus.{type Connection}

pub type Properties {
  Properties(os: String, browser: String, device: String)
}

pub type IdentifyData {
  IdentifyData(token: String, intents: Int, properties: Properties)
}

pub type IdentifyEvent {
  IdentifyEvent(op: Int, d: IdentifyData)
}

pub fn new(token: String, intents: Int) -> IdentifyEvent {
  IdentifyEvent(
    op: 2,
    d: IdentifyData(
      token:,
      intents:,
      properties: Properties(
        os: "linux",
        browser: "doorknob",
        device: "doorknob",
      ),
    ),
  )
}

pub fn to_string(event: IdentifyEvent) -> String {
  json.to_string(
    json.object([
      #("op", json.int(event.op)),
      #(
        "d",
        json.object([
          #("token", json.string(event.d.token)),
          #("intents", json.int(event.d.intents)),
          #(
            "properties",
            json.object([
              #("os", json.string(event.d.properties.os)),
              #("browser", json.string(event.d.properties.browser)),
              #("device", json.string(event.d.properties.device)),
            ]),
          ),
        ]),
      ),
    ]),
  )
}

pub fn send(event: IdentifyEvent, conn: Connection) -> Nil {
  let response = to_string(event) |> stratus.send_text_message(conn, _)

  let masked_event =
    string.length(event.d.token)
    |> string.repeat("*", _)
    |> new(event.d.intents)

  case response {
    Ok(_) ->
      logging.log(
        Info,
        "Identify event was successfully sent: " <> string.inspect(masked_event),
      )
    Error(_) ->
      logging.log(
        Err,
        "Identify event was unsuccessfully sent: "
          <> string.inspect(masked_event),
      )
  }
}
