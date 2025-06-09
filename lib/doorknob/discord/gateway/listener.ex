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

  defstruct [:conn, :id, :interval, :ref, :token, :websocket]

  @impl true
  def init(args) do
    Logger.info("Starting Discord Gateway API listener.")

    host = API.host()
    path = API.path()
    port = API.port()

    {:ok, conn} = Mint.HTTP.connect(:https, host, port, protocols: [:http1])
    {:ok, conn, ref} = Mint.WebSocket.upgrade(:wss, conn, path, [])

    http_reply_message = receive(do: (message -> message))

    {:ok, state} =
      case Mint.WebSocket.stream(conn, http_reply_message) do
        {:ok, conn,
         [
           {:status, ^ref, status},
           {:headers, ^ref, resp_headers},
           {:data, ^ref, data},
           {:done, ^ref}
         ]} ->
          {:ok, conn, websocket} = Mint.WebSocket.new(conn, ref, status, resp_headers)
          {:ok, websocket, [{:text, event}]} = Mint.WebSocket.decode(websocket, data)
          {:ok, decoded} = JSON.decode(event)

          Logger.debug("Decoded initial event: #{inspect(decoded)}.")

          state = %__MODULE__{conn: conn, ref: ref, token: args.token, websocket: websocket}

          Event.handle(decoded, state)

        {:ok, conn,
         [
           {:status, ^ref, status},
           {:headers, ^ref, resp_headers},
           {:done, ^ref}
         ]} ->
          {:ok, conn, websocket} = Mint.WebSocket.new(conn, ref, status, resp_headers)

          state = %__MODULE__{conn: conn, ref: ref, token: args.token, websocket: websocket}

          {:ok, state}
      end

    Logger.info("Started Discord Gateway API listener.")

    {:ok, state}
  end

  @impl true
  def handle_cast({:send, {:text, _event} = frame}, %__MODULE__{} = state) do
    {:ok, websocket, data} = Mint.WebSocket.encode(state.websocket, frame)
    {:ok, conn} = Mint.WebSocket.stream_request_body(state.conn, state.ref, data)

    state = put_in(state.conn, conn)
    state = put_in(state.websocket, websocket)

    Logger.debug("Sent text frame: #{inspect(frame)}.")

    {:noreply, state}
  end

  @impl true
  def handle_info(:heartbeat, %__MODULE__{} = state) do
    Event.heartbeat()

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    ref = state.ref

    {:ok, conn, [{:data, ^ref, data}]} = Mint.WebSocket.stream(state.conn, msg)
    {:ok, websocket, frames} = Mint.WebSocket.decode(state.websocket, data)

    state = put_in(state.conn, conn)
    state = put_in(state.websocket, websocket)

    state =
      Enum.reduce(frames, state, fn
        {:close, _code, _reason} = frame, state ->
          Logger.error("Received close frame: #{inspect(frame)}.")
          state

        {:text, event} = frame, state ->
          Logger.debug("Received text frame: #{inspect(frame)}.")
          {:ok, decoded} = JSON.decode(event)
          {:ok, state} = Event.handle(decoded, state)
          state

        frame, state ->
          Logger.warning("Received unknown frame: #{inspect(frame)}.")
          state
      end)

    {:noreply, state}
  end

  def send(encoded) do
    GenServer.cast(__MODULE__, {:send, {:text, encoded}})
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
end
