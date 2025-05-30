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
  The listener for the Discord Gateway API.
  """

  require Logger

  use GenServer

  defstruct [:interval, :pid, :protocol, :ref]

  @impl true
  def init(_args) do
    Logger.info("Starting Discord Gateway API listener.")

    opts = %{
      protocols: [:http]
    }

    {:ok, pid} = :gun.open(:binary.bin_to_list("gateway.discord.gg"), 443, opts)
    {:ok, protocol} = :gun.await_up(pid)
    ref = :gun.ws_upgrade(pid, :binary.bin_to_list("/?v=10&encoding=json"))

    state = %__MODULE__{interval: 0, pid: pid, protocol: protocol, ref: ref}

    {:ok, state}
  end

  @impl true
  def handle_info({:gun_ws, pid, ref, {:text, data}}, state) do
    state = put_in(state.pid, pid)
    state = put_in(state.ref, ref)

    Logger.debug("Received text frame: #{inspect(data)}.")

    {:ok, decoded} = JSON.decode(data)
    Logger.debug("Decoded data: #{inspect(decoded)}.")

    state = handle_event(decoded, state)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Received message: #{inspect(msg)}.")

    {:noreply, state}
  end

  defp handle_event(%{"op" => 0, "t" => type}, state) do
    Logger.info("Received dispatch event: #{inspect(type)}.")

    state
  end

  defp handle_event(%{"op" => 1}, state) do
    Logger.warning("Received heartbeat event.")

    state
  end

  defp handle_event(%{"op" => 7}, state) do
    Logger.warning("Received reconnect event.")

    state
  end

  defp handle_event(%{"op" => 9}, state) do
    Logger.warning("Received invalid session event.")

    state
  end

  defp handle_event(%{"op" => 10, "d" => data}, state) do
    Logger.info("Received hello event.")

    state = put_in(state.interval, data["heartbeat_interval"])

    identify(state)
    heartbeat(state)

    state
  end

  defp handle_event(%{"op" => 11}, state) do
    Logger.info("Received heartbeat acknowledgement event.")

    heartbeat(state)

    state
  end

  defp handle_event(event, state) do
    Logger.warning("Received unhandled event: #{inspect(event)}.")

    state
  end

  defp heartbeat(state) do
    encoded = JSON.encode!(%{op: 1, d: 0})
    :gun.ws_send(state.pid, state.ref, {:text, encoded})

    Logger.info("Sent heartbeat event.")
  end

  defp identify(state) do
    encoded =
      JSON.encode!(%{
        op: 2,
        d: %{
          token: System.get_env("DISCORD_TOKEN"),
          intents: 513,
          properties: %{os: "linux", browser: "doorknob", device: "doorknob"}
        }
      })

    :gun.ws_send(state.pid, state.ref, {:text, encoded})

    Logger.info("Sent identify event.")
  end

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [])
  end
end
