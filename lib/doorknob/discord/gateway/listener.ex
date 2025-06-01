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

defmodule Doorknob.Discord.Gateway.Listener do
  @moduledoc """
  Listener for the Discord Gateway API.
  """

  alias Doorknob.Discord.Gateway.API
  alias Doorknob.Discord.Gateway.Event

  require Logger

  use GenServer

  defstruct [:id, :interval, :pid, :ref, :token]

  @impl true
  def init(args) do
    Logger.info("Starting Discord Gateway API listener.")

    opts = %{
      protocols: [:http]
    }

    host = API.host()
    path = API.path()
    port = API.port()

    {:ok, pid} = :gun.open(host, port, opts)
    {:ok, :http} = :gun.await_up(pid)
    ref = :gun.ws_upgrade(pid, path)

    state = %__MODULE__{pid: pid, ref: ref, token: args.token}

    {:ok, state}
  end

  @impl true
  def handle_cast({:send, frame}, state) do
    :gun.ws_send(state.pid, state.ref, frame)

    Logger.debug("Sent frame: #{inspect(frame)}")

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_upgrade, pid, ref, ["websocket"], _headers}, state) do
    state = put_in(state.pid, pid)
    state = put_in(state.ref, ref)

    Logger.info("Successfully started Discord Gateway API listener.")

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, pid, ref, {:text, data}}, state) do
    state = put_in(state.pid, pid)
    state = put_in(state.ref, ref)

    Logger.debug("Received text frame: #{inspect(data)}.")

    {:ok, decoded} = JSON.decode(data)
    Logger.debug("Decoded data: #{inspect(decoded)}.")

    state = Event.handle(decoded, state)

    {:noreply, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    Event.heartbeat()

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received Gateway message: #{inspect(msg)}.")

    {:noreply, state}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
