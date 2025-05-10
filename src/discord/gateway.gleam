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

import discord/event/heartbeat
import discord/event/hello
import discord/event/identify
import discord/utility
import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/http/request
import gleam/int
import gleam/option
import gleam/otp/actor
import gleam/string
import logging
import repeatedly
import stratus

pub type State {
  State(initialized: Bool, s: Int)
}

fn init() -> #(State, option.Option(process.Selector(String))) {
  let initial_state = State(initialized: False, s: 0)

  logging.log(logging.Debug, "Initial state: " <> string.inspect(initial_state))

  #(initial_state, option.None)
}

fn handle_binary(msg: BitArray, state: State) -> actor.Next(String, State) {
  let assert Ok(content) = bit_array.to_string(msg)

  logging.log(logging.Debug, "Received binary message: " <> content)

  actor.continue(state)
}

fn handle_text(
  msg: String,
  state: State,
  conn: stratus.Connection,
) -> actor.Next(String, State) {
  logging.log(logging.Debug, "Received text message: " <> msg)
  logging.log(logging.Debug, "Current state: " <> string.inspect(state))

  case state.initialized {
    False -> {
      let heartbeat_interval =
        msg |> hello.from_string() |> hello.heartbeat_interval()

      let heartbeat_message =
        state.s |> heartbeat.new() |> heartbeat.to_string()

      process.start(
        fn() {
          repeatedly.call(heartbeat_interval, Nil, fn(_state, count) {
            let response = stratus.send_text_message(conn, heartbeat_message)

            let total = int.to_string(count + 1)

            case response {
              Ok(_) ->
                logging.log(
                  logging.Info,
                  "Heartbeat event #" <> total <> " was successfully sent",
                )
              Error(_) ->
                logging.log(
                  logging.Error,
                  "Heartbeat event #" <> total <> " was unsuccessfully sent",
                )
            }
          })
        },
        False,
      )

      let identify_message =
        utility.token() |> identify.new(513) |> identify.to_string()

      let response = stratus.send_text_message(conn, identify_message)

      case response {
        Ok(_) ->
          logging.log(logging.Info, "Identify event was successfully sent")
        Error(_) ->
          logging.log(logging.Error, "Identify event was unsuccessfully sent")
      }

      let state = State(initialized: True, s: state.s)

      actor.continue(state)
    }
    True -> {
      actor.continue(state)
    }
  }
}

fn handle_user(msg: String, state: State) -> actor.Next(String, State) {
  logging.log(logging.Debug, "Received user message: " <> msg)
  actor.continue(state)
}

fn loop(
  msg: stratus.Message(String),
  state: State,
  conn: stratus.Connection,
) -> actor.Next(String, State) {
  case msg {
    stratus.Binary(msg) -> handle_binary(msg, state)
    stratus.Text(msg) -> handle_text(msg, state, conn)
    stratus.User(msg) -> handle_user(msg, state)
  }
}

fn on_close(state: State) -> Nil {
  logging.log(
    logging.Error,
    "Gateway connection was unexpectedly closed: " <> string.inspect(state),
  )
}

pub fn start() -> Nil {
  logging.log(logging.Info, "Gateway process is starting")

  let assert Ok(req) =
    request.to("https://gateway.discord.gg?v=10&encoding=json")

  req
  |> request.set_header(
    "user-agent",
    "Doorknob (https://github.com/theomund/doorknob, 0.1.0)",
  )

  let builder =
    stratus.websocket(request: req, init:, loop:)
    |> stratus.on_close(on_close)

  let assert Ok(subj) = stratus.initialize(builder)

  let done =
    process.new_selector()
    |> process.selecting_process_down(
      process.monitor_process(process.subject_owner(subj)),
      function.identity,
    )
    |> process.select_forever

  logging.log(logging.Info, "Gateway process exited: " <> string.inspect(done))
}
