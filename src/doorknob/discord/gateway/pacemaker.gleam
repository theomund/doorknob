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

import doorknob/discord/gateway/mailbox.{
  type ListenerMessage, type PacemakerMessage, Done, Heartbeat, Interval,
}
import gleam/erlang/process.{type Subject}
import gleam/otp/actor.{type Next}
import gleam/string
import logging.{Debug}

type State {
  State(count: Int, interval: Int, listener: Subject(ListenerMessage))
}

fn handle_done_message(state: State) -> State {
  logging.log(Debug, "Received done message")

  let new_state = State(..state, count: state.count + 1)

  process.send_after(
    new_state.listener,
    new_state.interval,
    Heartbeat(new_state.count),
  )

  new_state
}

fn handle_interval_message(state: State, duration: Int) -> State {
  logging.log(Debug, "Received interval message")

  let new_state = State(..state, interval: duration)

  process.send_after(
    new_state.listener,
    new_state.interval,
    Heartbeat(new_state.count),
  )

  new_state
}

fn loop(msg: PacemakerMessage, state: State) -> Next(PacemakerMessage, State) {
  logging.log(Debug, "Current pacemaker state: " <> string.inspect(state))

  let new_state = case msg {
    Done -> handle_done_message(state)
    Interval(duration) -> handle_interval_message(state, duration)
  }

  actor.continue(new_state)
}

pub fn new(listener: Subject(ListenerMessage)) -> Subject(PacemakerMessage) {
  let state = State(count: 1, interval: 0, listener:)

  let assert Ok(subject) = actor.start(state, loop)

  subject
}
