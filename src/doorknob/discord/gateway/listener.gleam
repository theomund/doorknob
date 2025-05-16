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
import doorknob/discord/gateway/event/heartbeat
import doorknob/discord/gateway/event/hello
import doorknob/discord/gateway/event/identify
import doorknob/discord/gateway/event/unknown
import doorknob/discord/gateway/mailbox
import doorknob/discord/gateway/pacemaker
import gleam/bit_array
import gleam/erlang/process
import gleam/function
import gleam/http/request
import gleam/option
import gleam/otp/actor
import gleam/string
import logging
import stratus

pub type State {
  State(
    initialized: Bool,
    pacemaker: process.Subject(mailbox.Message),
    sequence: Int,
  )
}

fn init() -> #(State, option.Option(process.Selector(mailbox.Message))) {
  let self = process.new_subject()

  let subject = pacemaker.new(self)

  let state = State(initialized: False, pacemaker: subject, sequence: 0)

  logging.log(logging.Debug, "Initial state: " <> string.inspect(state))

  let selector =
    process.new_selector()
    |> process.selecting(self, function.identity)

  #(state, option.Some(selector))
}

fn handle_binary(
  msg: BitArray,
  state: State,
) -> actor.Next(mailbox.Message, State) {
  let assert Ok(content) = bit_array.to_string(msg)

  logging.log(logging.Debug, "Received binary message: " <> content)

  actor.continue(state)
}

fn handle_text(
  msg: String,
  state: State,
  conn: stratus.Connection,
) -> actor.Next(mailbox.Message, State) {
  logging.log(logging.Debug, "Received text message: " <> msg)

  case state.initialized {
    False -> {
      let interval = hello.from_string(msg) |> hello.heartbeat_interval()

      process.send(state.pacemaker, mailbox.Interval(interval))

      authentication.token() |> identify.new(513) |> identify.send(conn)

      let new_state =
        State(
          initialized: True,
          pacemaker: state.pacemaker,
          sequence: state.sequence,
        )

      actor.continue(new_state)
    }
    True -> {
      let event = unknown.from_string(msg)

      case unknown.opcode(event) {
        0 ->
          logging.log(
            logging.Info,
            "Received a dispatch event: " <> string.inspect(event),
          )
        1 ->
          logging.log(
            logging.Info,
            "Received a heartbeat event: " <> string.inspect(event),
          )
        7 ->
          logging.log(
            logging.Warning,
            "Receive a reconnect event: " <> string.inspect(event),
          )
        9 ->
          logging.log(
            logging.Error,
            "Received an invalid session event: " <> string.inspect(event),
          )
        10 ->
          logging.log(
            logging.Info,
            "Received a hello event: " <> string.inspect(event),
          )
        11 ->
          logging.log(
            logging.Info,
            "Received an acknowledgement event: " <> string.inspect(event),
          )
        _ ->
          logging.log(
            logging.Warning,
            "Received an unhandled event: " <> string.inspect(event),
          )
      }

      case unknown.sequence(event) {
        option.None -> actor.continue(state)
        option.Some(number) -> {
          let new_state =
            State(
              initialized: True,
              pacemaker: state.pacemaker,
              sequence: number,
            )

          actor.continue(new_state)
        }
      }
    }
  }
}

fn handle_user(
  msg: mailbox.Message,
  state: State,
  conn: stratus.Connection,
) -> actor.Next(mailbox.Message, State) {
  case msg {
    mailbox.Heartbeat(count) -> {
      logging.log(
        logging.Debug,
        "Handling heartbeat message: " <> string.inspect(msg),
      )

      heartbeat.new(state.sequence) |> heartbeat.send(conn, count)

      process.send(state.pacemaker, mailbox.Done)
    }
    _ -> Nil
  }

  actor.continue(state)
}

fn loop(
  msg: stratus.Message(mailbox.Message),
  state: State,
  conn: stratus.Connection,
) -> actor.Next(mailbox.Message, State) {
  logging.log(
    logging.Debug,
    "Current listener state: " <> string.inspect(state),
  )

  case msg {
    stratus.Binary(msg) -> handle_binary(msg, state)
    stratus.Text(msg) -> handle_text(msg, state, conn)
    stratus.User(msg) -> handle_user(msg, state, conn)
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

  let assert Ok(subject) = stratus.initialize(builder)

  let done =
    process.new_selector()
    |> process.selecting_process_down(
      process.monitor_process(process.subject_owner(subject)),
      function.identity,
    )
    |> process.select_forever

  logging.log(logging.Info, "Gateway process exited: " <> string.inspect(done))
}
