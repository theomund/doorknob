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
  Listener for the Discord HTTP API.
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
  def handle_call({:get, path}, _from, state) do
    headers = API.headers(state)

    ref = :gun.get(state.pid, path, headers)

    Logger.debug("Sent GET request: (path: #{path}, headers: #{inspect(headers)}).")

    {:ok, body} = :gun.await_body(state.pid, ref)

    {:ok, decoded} = JSON.decode(body)

    {:reply, decoded, state}
  end

  @impl true
  def handle_cast({:post, path, body}, state) do
    headers = API.headers(state)

    :gun.post(state.pid, path, headers, body)

    Logger.debug(
      "Sent POST request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:patch, path, body}, state) do
    headers = API.headers(state)

    :gun.patch(state.pid, path, headers, body)

    Logger.debug(
      "Sent PATCH request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, path, body}, state) do
    headers = API.headers(state)

    :gun.put(state.pid, path, headers, body)

    Logger.debug(
      "Sent PUT request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_data, _pid, _ref, _fin, data}, state) do
    if data != "" do
      {:ok, decoded} = JSON.decode(data)
      Logger.debug("Received HTTP response with data: #{inspect(decoded)}.")
    else
      Logger.debug("Received HTTP response with no data.")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_response, _pid, _ref, _fin, status, _headers}, state) do
    message = "Received HTTP response with status code #{status}."

    if status == 200 do
      Logger.debug(message)
    else
      Logger.error(message)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received HTTP message: #{inspect(msg)}.")

    {:noreply, state}
  end

  def get(path) do
    GenServer.call(__MODULE__, {:get, path})
  end

  def patch(path, body) do
    GenServer.cast(__MODULE__, {:patch, path, body})
  end

  def post(path, body) do
    GenServer.cast(__MODULE__, {:post, path, body})
  end

  def put(path, body) do
    GenServer.cast(__MODULE__, {:put, path, body})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
