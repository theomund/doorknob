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

import doorknob/discord/http/api
import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/string

type Gateway {
  Gateway(url: String)
}

pub fn url(version: Int, encoding: String) -> String {
  let assert Ok(req) = api.url(10, "/gateway") |> request.to()

  request.set_header(
    req,
    "user-agent",
    "Doorknob (https://github.com/theomund/doorknob, 0.1.0)",
  )

  let assert Ok(resp) = httpc.send(req)

  let decoder = {
    use url <- decode.field("url", decode.string)
    decode.success(Gateway(url:))
  }

  let assert Ok(gateway) = json.parse(from: resp.body, using: decoder)

  gateway.url
  |> string.replace(each: "wss", with: "https")
  <> "?v="
  <> int.to_string(version)
  <> "&encoding="
  <> encoding
}
