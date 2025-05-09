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

import discord/event.{State}
import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/http/request
import gleam/option.{None}
import gleam/otp/actor
import gleam/string
import logging.{Debug, Error, Info}
import stratus

pub fn start() -> Nil {
  logging.log(Info, "Starting Discord Gateway API listener")

  let assert Ok(req) =
    request.to("https://gateway.discord.gg?v=10&encoding=json")

  req
  |> request.set_header(
    "user-agent",
    "Doorknob (https://github.com/theomund/doorknob, 0.1.0)",
  )

  let initial_state = State(initialized: False, s: 0)

  let builder =
    stratus.websocket(
      request: req,
      init: fn() {
        logging.log(Debug, "Initializing the WebSocket builder")
        #(initial_state, None)
      },
      loop: fn(msg, state, _conn) {
        case msg {
          stratus.Binary(msg) -> {
            let assert Ok(content) = bit_array.to_string(msg)
            logging.log(Debug, "Received binary message: " <> content)
            actor.continue(state)
          }
          stratus.Text(msg) -> {
            logging.log(Debug, "Received text message: " <> msg)
            case state.initialized {
              False -> logging.log(Debug, "State is not initialized")
              True -> logging.log(Debug, "State is initialized")
            }
            actor.continue(state)
          }
          stratus.User(msg) -> {
            logging.log(Debug, "Received user message: " <> msg)
            actor.continue(state)
          }
        }
      },
    )
    |> stratus.on_close(fn(_state) {
      logging.log(Error, "WebSocket connection was unexpectedly closed")
    })

  let assert Ok(subj) = stratus.initialize(builder)

  let done =
    process.new_selector()
    |> process.selecting_process_down(
      process.monitor_process(process.subject_owner(subj)),
      function.identity,
    )
    |> process.select_forever

  logging.log(Info, "WebSocket process exited: " <> string.inspect(done))
}
