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

defmodule Doorknob.Discord.HTTP.Listener do
  @moduledoc """
  The listener for the Discord HTTP API.
  """

  alias Doorknob.Discord.HTTP.API

  require Logger

  use GenServer

  defstruct [:pid, :token]

  @impl true
  def init(args) do
    Logger.info("Starting Discord HTTP API listener.")

    host = API.host()
    port = API.port()

    {:ok, pid} = :gun.open(host, port)
    {:ok, :http2} = :gun.await_up(pid)

    state = %__MODULE__{pid: pid, token: args.token}

    Logger.info("Successfully started Discord HTTP API listener.")

    {:ok, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received HTTP message: #{inspect(msg)}.")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:post, path, body}, state) do
    headers = API.headers(state)

    :gun.post(state.pid, path, headers, body)

    Logger.debug(
      "Sent POST request: {path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)}}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, path, body}, state) do
    headers = API.headers(state)

    :gun.put(state.pid, path, headers, body)

    Logger.debug(
      "Sent PUT request: {path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)}}"
    )

    {:noreply, state}
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
