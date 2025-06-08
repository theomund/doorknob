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

defmodule Doorknob.OpenAI.Listener do
  @moduledoc """
  Listener for the OpenAI API.
  """

  alias Doorknob.OpenAI.API

  require Logger

  use GenServer

  defstruct [:context, :key]

  @impl true
  def init(args) do
    Logger.info("Starting OpenAI API listener.")

    context = [%{role: "developer", content: args.prompt}]
    state = %__MODULE__{context: context, key: args.key}

    Logger.info("Successfully started OpenAI API listener.")

    {:ok, state}
  end

  @impl true
  def handle_call({:post, path, body}, _from, %__MODULE__{} = state) do
    headers = API.headers(state.key)

    Logger.debug(
      "Sending POST request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    response = Req.post!(path, headers: headers, json: body)

    Logger.debug("Received POST response: #{inspect(response)}.")

    {:reply, response.body, state}
  end

  @impl true
  def handle_call({:update_context, message}, _from, %__MODULE__{} = state) do
    state = put_in(state.context, state.context ++ [message])

    Logger.debug("Updated context: #{inspect(state.context)}.")

    {:reply, state.context, state}
  end

  def post(path, body) do
    timeout = API.timeout()

    GenServer.call(__MODULE__, {:post, path, body}, timeout)
  end

  def update_context(role, message) do
    GenServer.call(__MODULE__, {:update_context, %{role: role, content: message}})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
