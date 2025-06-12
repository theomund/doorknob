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

  defstruct [:token]

  @impl true
  def init(args) do
    Logger.info("Starting Discord HTTP API listener.")

    state = %__MODULE__{token: args.token}

    Logger.info("Successfully started Discord HTTP API listener.")

    {:ok, state}
  end

  @impl true
  def handle_call({:get, path}, _from, %__MODULE__{} = state) do
    headers = API.headers(state.token)

    Logger.debug("Sending GET request: (path: #{path}, headers: #{inspect(headers)}).")

    response = Req.get!(path, headers: headers)

    Logger.debug("Received GET response: #{inspect(response)}")

    {:reply, response.body, state}
  end

  @impl true
  def handle_cast({:post, path, body}, %__MODULE__{} = state) do
    headers = API.headers(state.token)

    Logger.debug(
      "Sending POST request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    response = Req.post!(path, headers: headers, json: body)

    Logger.debug("Received POST response: #{inspect(response)}.")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:patch, path, body}, %__MODULE__{} = state) do
    headers = API.headers(state.token)

    Logger.debug(
      "Sending PATCH request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    response = Req.patch!(path, headers: headers, json: body)

    Logger.debug("Received PATCH response: #{inspect(response)}.")

    {:noreply, state}
  end

  @impl true
  def handle_cast({:put, path, body}, %__MODULE__{} = state) do
    headers = API.headers(state.token)

    Logger.debug(
      "Sending PUT request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    response = Req.put!(path, headers: headers, json: body)

    Logger.debug("Received PUT response: #{inspect(response)}.")

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
