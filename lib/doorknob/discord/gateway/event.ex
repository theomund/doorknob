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

defmodule Doorknob.Discord.Gateway.Event do
  @moduledoc """
  Functions for handling Gateway API events.
  """

  alias Doorknob.Discord.Gateway.Listener
  alias Doorknob.Discord.HTTP.Command
  alias Doorknob.Discord.HTTP.Interaction

  require Logger

  def handle(
        %{
          "op" => 0,
          "d" => %{
            "data" => %{"name" => name, "options" => options},
            "channel_id" => channel_id,
            "guild_id" => guild_id,
            "id" => id,
            "member" => %{"user" => %{"id" => user_id}},
            "token" => token
          },
          "t" => "INTERACTION_CREATE"
        },
        state
      ) do
    Logger.info("Received interaction create event.")

    context = %{
      name: name,
      channel_id: channel_id,
      guild_id: guild_id,
      id: id,
      options: options,
      token: token,
      user_id: user_id
    }

    Interaction.respond(context)

    state
  end

  def handle(%{"op" => 0, "t" => "MESSAGE_CREATE"}, state) do
    Logger.info("Received message create event.")

    state
  end

  def handle(
        %{
          "op" => 0,
          "d" => %{"application" => %{"id" => application_id}, "guilds" => guilds},
          "t" => "READY"
        },
        state
      ) do
    Logger.info("Received ready event.")

    state = put_in(state.id, application_id)

    :ok = Command.register(state.id, guilds)

    state
  end

  def handle(%{"op" => 0, "t" => type}, state) do
    Logger.info("Received dispatch event: #{inspect(type)}.")

    state
  end

  def handle(%{"op" => 1}, state) do
    Logger.warning("Received heartbeat event.")

    state
  end

  def handle(%{"op" => 7}, state) do
    Logger.warning("Received reconnect event.")

    state
  end

  def handle(%{"op" => 9}, state) do
    Logger.warning("Received invalid session event.")

    state
  end

  def handle(%{"op" => 10, "d" => data}, state) do
    Logger.info("Received hello event.")

    state = put_in(state.interval, data["heartbeat_interval"])

    identify(state.token)

    Process.send_after(Listener, :heartbeat, state.interval)

    state
  end

  def handle(%{"op" => 11}, state) do
    Logger.info("Received heartbeat acknowledgement event.")

    Process.send_after(Listener, :heartbeat, state.interval)

    state
  end

  def handle(event, state) do
    Logger.warning("Received unhandled event: #{inspect(event)}.")

    state
  end

  def heartbeat() do
    encoded = JSON.encode!(%{op: 1, d: 0})

    GenServer.cast(Listener, {:send, {:text, encoded}})

    Logger.info("Sent heartbeat event.")
  end

  def identify(token) do
    encoded =
      JSON.encode!(%{
        op: 2,
        d: %{
          token: token,
          intents: 33_409,
          properties: %{os: "linux", browser: "doorknob", device: "doorknob"}
        }
      })

    GenServer.cast(Listener, {:send, {:text, encoded}})

    Logger.info("Sent identify event.")
  end

  def update_voice_state(channel_id, guild_id, self_deaf, self_mute) do
    encoded =
      JSON.encode!(%{
        op: 4,
        d: %{
          channel_id: channel_id,
          guild_id: guild_id,
          self_deaf: self_deaf,
          self_mute: self_mute
        }
      })

    GenServer.cast(Listener, {:send, {:text, encoded}})

    Logger.info("Sent voice state update.")
  end
end
