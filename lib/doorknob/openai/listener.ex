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

  defstruct [:context, :key, :pid, :ref]

  @impl true
  def init(args) do
    Logger.info("Starting OpenAI API listener.")

    host = API.host()
    port = API.port()

    {:ok, pid} = :gun.open(host, port)
    {:ok, ref} = :gun.await_up(pid)

    context = [%{role: "developer", content: args.prompt}]

    state = %__MODULE__{context: context, key: args.key, pid: pid, ref: ref}

    Logger.info("Successfully started OpenAI API listener.")

    {:ok, state}
  end

  @impl true
  def handle_call({:post, path, body, timeout}, _from, %__MODULE__{} = state) do
    headers = API.headers(state)
    ref = :gun.post(state.pid, path, headers, body)

    Logger.debug(
      "Sent POST request: (path: #{path}, headers: #{inspect(headers)}, body: #{inspect(body)})."
    )

    {:ok, body} = :gun.await_body(state.pid, ref, timeout)
    {:ok, decoded} = JSON.decode(body)

    {:reply, decoded, state}
  end

  @impl true
  def handle_call({:update_context, message}, _from, %__MODULE__{} = state) do
    state = put_in(state.context, state.context ++ [message])

    Logger.debug("Updated context: #{inspect(state.context)}.")

    {:reply, state.context, state}
  end

  @impl true
  def handle_info({:gun_data, pid, ref, _fin, data}, %__MODULE__{pid: pid, ref: ref} = state) do
    if data != "" do
      {:ok, decoded} = JSON.decode(data)
      Logger.debug("Received HTTP response with data: #{inspect(decoded)}.")
    else
      Logger.debug("Received HTTP response with no data.")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:gun_response, pid, ref, _fin, status, _headers},
        %__MODULE__{pid: pid, ref: ref} = state
      ) do
    message = "Received HTTP response with status code #{status}."

    case status do
      200 -> Logger.debug(message)
      204 -> Logger.debug(message)
      _ -> Logger.error(message)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, %__MODULE__{} = state) do
    Logger.debug("Received HTTP message: #{inspect(msg)}.")

    {:noreply, state}
  end

  def post(path, body) do
    timeout = API.timeout()
    GenServer.call(__MODULE__, {:post, path, body, timeout}, timeout)
  end

  def update_context(role, message) do
    GenServer.call(__MODULE__, {:update_context, %{role: role, content: message}})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
