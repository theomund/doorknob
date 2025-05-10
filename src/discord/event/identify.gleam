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

pub type Properties {
  Properties(os: String, browser: String, device: String)
}

pub type Data {
  Data(token: String, intents: Int, properties: Properties)
}

pub type Event {
  Event(op: Int, d: Data)
}

pub fn new(token: String, intents: Int) -> Event {
  Event(
    op: 2,
    d: Data(
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

pub fn to_string(event: Event) -> String {
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
