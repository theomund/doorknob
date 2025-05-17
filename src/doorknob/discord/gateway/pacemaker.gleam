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

import doorknob/discord/gateway/mailbox
import gleam/erlang/process
import gleam/otp/actor
import gleam/string
import logging

pub type State {
  State(count: Int, interval: Int, listener: process.Subject(mailbox.Message))
}

pub fn loop(
  msg: mailbox.Message,
  state: State,
) -> actor.Next(mailbox.Message, State) {
  logging.log(
    logging.Debug,
    "Current pacemaker state: " <> string.inspect(state),
  )

  case msg {
    mailbox.Done -> {
      logging.log(logging.Debug, "Received done message")

      let new_state =
        State(
          count: state.count + 1,
          interval: state.interval,
          listener: state.listener,
        )

      process.send_after(
        new_state.listener,
        new_state.interval,
        mailbox.Heartbeat(new_state.count),
      )

      actor.continue(new_state)
    }
    mailbox.Interval(duration) -> {
      logging.log(
        logging.Debug,
        "Handling interval message: " <> string.inspect(msg),
      )

      let new_state =
        State(count: state.count, interval: duration, listener: state.listener)

      process.send_after(
        new_state.listener,
        new_state.interval,
        mailbox.Heartbeat(new_state.count),
      )

      actor.continue(new_state)
    }
    _ -> actor.continue(state)
  }
}

pub fn new(
  listener: process.Subject(mailbox.Message),
) -> process.Subject(mailbox.Message) {
  let state = State(count: 1, interval: 0, listener:)

  let assert Ok(subject) = actor.start(state, loop)

  subject
}
