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

import doorknob/discord/authentication
import doorknob/discord/gateway/api
import doorknob/discord/gateway/event/heartbeat
import doorknob/discord/gateway/event/hello
import doorknob/discord/gateway/event/identify
import doorknob/discord/gateway/event/unknown.{type UnknownEvent}
import doorknob/discord/gateway/mailbox.{
  type ListenerMessage, type PacemakerMessage, Done, Heartbeat, Interval,
}
import doorknob/discord/gateway/pacemaker
import gleam/bit_array
import gleam/erlang/process.{type Selector, type Subject}
import gleam/function
import gleam/http/request
import gleam/option.{type Option, None, Some}
import gleam/otp/actor.{type Next}
import gleam/string
import logging.{Debug, Error, Info}
import stratus.{type Connection, type Message, Binary, Text, User}

type State {
  State(initialized: Bool, pacemaker: Subject(PacemakerMessage), sequence: Int)
}

fn init() -> #(State, Option(Selector(ListenerMessage))) {
  let self = process.new_subject()

  let subject = pacemaker.new(self)

  let state = State(initialized: False, pacemaker: subject, sequence: 0)

  logging.log(Debug, "Initial state: " <> string.inspect(state))

  let selector =
    process.new_selector()
    |> process.selecting(self, function.identity)

  #(state, Some(selector))
}

fn handle_binary(msg: BitArray, state: State) -> Next(ListenerMessage, State) {
  let assert Ok(content) = bit_array.to_string(msg)

  logging.log(Debug, "Received binary message: " <> content)

  actor.continue(state)
}

fn handle_dispatch_event(msg: String, state: State) -> State {
  let event = unknown.from_string(msg)

  logging.log(Info, "Received a dispatch event: " <> string.inspect(event))

  state
}

fn handle_heartbeat_event(msg: String, state: State) -> State {
  let event = unknown.from_string(msg)

  logging.log(Info, "Received a heartbeat event: " <> string.inspect(event))

  state
}

fn handle_reconnect_event(msg: String, state: State) -> State {
  let event = unknown.from_string(msg)

  logging.log(Info, "Received a reconnect event: " <> string.inspect(event))

  state
}

fn handle_invalid_session_event(msg: String, state: State) -> State {
  let event = unknown.from_string(msg)

  logging.log(
    Info,
    "Received an invalid session event: " <> string.inspect(event),
  )

  state
}

fn handle_hello_event(msg: String, state: State, conn: Connection) -> State {
  let event = hello.from_string(msg)

  logging.log(Info, "Received a hello event: " <> string.inspect(event))

  case state.initialized {
    False -> {
      let interval = event |> hello.heartbeat_interval()

      process.send(state.pacemaker, Interval(interval))

      let intents = 513

      authentication.token() |> identify.new(intents) |> identify.send(conn)

      State(..state, initialized: True)
    }
    True -> {
      logging.log(Debug, "Skipping initialization logic")

      state
    }
  }
}

fn handle_acknowledgement_event(msg: String, state: State) -> State {
  let event = unknown.from_string(msg)

  logging.log(
    Info,
    "Received an acknowledgement event: " <> string.inspect(event),
  )

  process.send(state.pacemaker, Done)

  state
}

fn handle_unknown_event(event: UnknownEvent, state: State) -> State {
  logging.log(Info, "Received an unknown event: " <> string.inspect(event))

  case unknown.sequence(event) {
    None -> state
    Some(number) -> State(..state, sequence: number)
  }
}

fn handle_text(
  msg: String,
  state: State,
  conn: Connection,
) -> Next(ListenerMessage, State) {
  logging.log(Debug, "Received text message: " <> msg)

  let event = unknown.from_string(msg)

  let new_state = case unknown.opcode(event) {
    0 -> handle_dispatch_event(msg, state)
    1 -> handle_heartbeat_event(msg, state)
    7 -> handle_reconnect_event(msg, state)
    9 -> handle_invalid_session_event(msg, state)
    10 -> handle_hello_event(msg, state, conn)
    11 -> handle_acknowledgement_event(msg, state)
    _ -> handle_unknown_event(event, state)
  }

  actor.continue(new_state)
}

fn handle_heartbeat_message(count: Int, state: State, conn: Connection) -> Nil {
  logging.log(Debug, "Received a heartbeat message")

  heartbeat.new(state.sequence) |> heartbeat.send(conn, count)
}

fn handle_user(
  msg: ListenerMessage,
  state: State,
  conn: Connection,
) -> Next(ListenerMessage, State) {
  case msg {
    Heartbeat(count) -> handle_heartbeat_message(count, state, conn)
  }

  actor.continue(state)
}

fn loop(
  msg: Message(ListenerMessage),
  state: State,
  conn: Connection,
) -> Next(ListenerMessage, State) {
  logging.log(Debug, "Current listener state: " <> string.inspect(state))

  case msg {
    Binary(msg) -> handle_binary(msg, state)
    Text(msg) -> handle_text(msg, state, conn)
    User(msg) -> handle_user(msg, state, conn)
  }
}

fn on_close(state: State) -> Nil {
  logging.log(
    Error,
    "Gateway connection was unexpectedly closed: " <> string.inspect(state),
  )
}

pub fn start() -> Nil {
  logging.log(Info, "Gateway process started")

  let assert Ok(req) = api.url(10, "json") |> request.to()

  request.set_header(
    req,
    "user-agent",
    "Doorknob (https://github.com/theomund/doorknob, 0.1.0)",
  )

  let builder =
    stratus.websocket(request: req, init:, loop:)
    |> stratus.on_close(on_close)

  let assert Ok(subject) = stratus.initialize(builder)

  let done =
    process.new_selector()
    |> process.selecting_process_down(
      process.monitor_process(process.subject_owner(subject)),
      function.identity,
    )
    |> process.select_forever

  logging.log(Info, "Gateway process exited: " <> string.inspect(done))
}
