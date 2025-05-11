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

import discord/authentication
import discord/event/heartbeat
import discord/event/hello
import discord/event/identify
import discord/event/unknown
import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/http/request
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

  logging.log(logging.Debug, "Current state: " <> string.inspect(state))
  logging.log(logging.Debug, "Received binary message: " <> content)

  actor.continue(state)
}

fn handle_text(
  msg: String,
  state: State,
  conn: stratus.Connection,
) -> actor.Next(String, State) {
  logging.log(logging.Debug, "Current state: " <> string.inspect(state))
  logging.log(logging.Debug, "Received text message: " <> msg)

  case state.initialized {
    False -> {
      let heartbeat_interval =
        hello.from_string(msg) |> hello.heartbeat_interval()

      process.start(
        fn() {
          repeatedly.call(heartbeat_interval, Nil, fn(_state, count) {
            heartbeat.new(state.s) |> heartbeat.send(conn, count)
          })
        },
        False,
      )

      authentication.token() |> identify.new(513) |> identify.send(conn)

      let new_state = State(initialized: True, s: state.s)

      actor.continue(new_state)
    }
    True -> {
      let event = unknown.from_string(msg)

      logging.log(
        logging.Warning,
        "Received unhandled event: " <> string.inspect(event),
      )

      case unknown.sequence(event) {
        option.None -> actor.continue(state)
        option.Some(s) -> {
          let new_state = State(initialized: state.initialized, s:)
          actor.continue(new_state)
        }
      }
    }
  }
}

fn handle_user(msg: String, state: State) -> actor.Next(String, State) {
  logging.log(logging.Debug, "Current state: " <> string.inspect(state))
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
  logging.log(logging.Info, "Gateway process started")

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
