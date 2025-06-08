# Doorknob - Artificial intelligence companion written in Elixir.
# Copyright (C) 2025 Theomund
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

defmodule Doorknob.Discord.Gateway.Event.Test do
  alias Doorknob.Discord.Gateway.Event
  alias Doorknob.Discord.Gateway.Listener

  use ExUnit.Case

  test "Handle Message Create" do
    event = %{"op" => 0, "t" => "MESSAGE_CREATE"}
    expected = %Listener{pid: 1}

    actual = Event.handle(event, expected)

    assert actual == expected
  end

  test "Handle Dispatch" do
    event = %{"op" => 0, "t" => "EXAMPLE_EVENT"}
    expected = %Listener{pid: 1}

    actual = Event.handle(event, expected)

    assert actual == expected
  end

  test "Handle Heartbeat" do
    event = %{"op" => 1}
    expected = %Listener{pid: 1}

    actual = Event.handle(event, expected)

    assert actual == expected
  end

  test "Handle Reconnect" do
    event = %{"op" => 7}
    expected = %Listener{pid: 1}

    actual = Event.handle(event, expected)

    assert actual == expected
  end

  test "Handle Invalid Session" do
    event = %{"op" => 9}
    expected = %Listener{pid: 1}

    actual = Event.handle(event, expected)

    assert actual == expected
  end

  test "Handle Unknown" do
    event = %{"op" => 12}
    expected = %Listener{pid: 1}

    actual = Event.handle(event, expected)

    assert actual == expected
  end
end
