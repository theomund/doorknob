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

defmodule Doorknob.Discord.HTTP.Interaction do
  @moduledoc """
  Functions for handling interactions.
  """

  alias Doorknob.Discord.Gateway.Event
  alias Doorknob.Discord.HTTP.API
  alias Doorknob.Discord.HTTP.Listener
  alias Doorknob.Discord.HTTP.Voice
  alias Doorknob.OpenAI.Chat

  require Logger

  def respond(context) do
    {timeliness, content} = handle(context)

    case timeliness do
      :punctual ->
        path = API.path("/interactions/#{context.id}/#{context.token}/callback")
        body = JSON.encode!(%{type: 4, data: %{content: content}})
        Logger.debug("Sending punctual interaction response: #{body}.")
        GenServer.cast(Listener, {:post, path, body})

      :delayed ->
        path = API.path("/webhooks/#{context.application_id}/#{context.token}/messages/@original")
        body = JSON.encode!(%{content: content})
        Logger.debug("Sending delayed interaction response: #{body}.")
        GenServer.cast(Listener, {:patch, path, body})
    end
  end

  defp delay(context) do
    path = API.path("/interactions/#{context.id}/#{context.token}/callback")

    body = JSON.encode!(%{type: 5})

    GenServer.cast(Listener, {:post, path, body})
  end

  defp handle(%{name: "chat"} = context) do
    Logger.debug("Handling chat command.")

    message =
      Enum.find_value(context.options, fn %{"name" => "message", "value" => value} -> value end)

    delay(context)

    {:ok, text} = Chat.create(message)

    {:delayed, ":speaking_head: **Doorknob responded:**\n\n*#{text}*"}
  end

  defp handle(%{name: "deafen"} = context) do
    Logger.debug("Handling deafen command.")

    {:ok, state} = Voice.current_state(context.guild_id)

    channel_id = state["channel_id"]
    guild_id = state["guild_id"]
    self_deaf = true
    self_mute = state["self_mute"]

    Event.update_voice_state(channel_id, guild_id, self_deaf, self_mute)

    {:punctual, ":ear_with_hearing_aid: **Doorknob has been deafened.**"}
  end

  defp handle(%{name: "join"} = context) do
    Logger.debug("Handling join command.")

    {:ok, state} = Voice.user_state(context.guild_id, context.user_id)

    channel_id = state["channel_id"]
    guild_id = state["guild_id"]
    self_deaf = false
    self_mute = false

    Event.update_voice_state(channel_id, guild_id, self_deaf, self_mute)

    {:punctual, ":wave: **Doorknob has joined the call.**"}
  end

  defp handle(%{name: "leave"} = context) do
    Logger.debug("Handling leave command.")

    {:ok, state} = Voice.current_state(context.guild_id)

    channel_id = nil
    guild_id = state["guild_id"]
    self_deaf = state["self_deaf"]
    self_mute = state["self_mute"]

    Event.update_voice_state(channel_id, guild_id, self_deaf, self_mute)

    {:punctual, ":door: **Doorknob has left the call.**"}
  end

  defp handle(%{name: "mute"} = context) do
    Logger.debug("Handling mute command.")

    {:ok, state} = Voice.current_state(context.guild_id)

    channel_id = state["channel_id"]
    guild_id = state["guild_id"]
    self_deaf = state["self_deaf"]
    self_mute = true

    Event.update_voice_state(channel_id, guild_id, self_deaf, self_mute)

    {:punctual, ":mute: **Doorknob has been muted.**"}
  end

  defp handle(%{name: "ping"}) do
    Logger.debug("Handling ping command.")

    {:punctual, ":white_check_mark: **Doorknob is online.**"}
  end

  defp handle(%{name: "undeafen"} = context) do
    Logger.debug("Handling undeafen command.")

    {:ok, state} = Voice.current_state(context.guild_id)

    channel_id = state["channel_id"]
    guild_id = state["guild_id"]
    self_deaf = false
    self_mute = state["self_mute"]

    Event.update_voice_state(channel_id, guild_id, self_deaf, self_mute)

    {:punctual, ":ear: **Doorknob has been undeafened.**"}
  end

  defp handle(%{name: "unmute"} = context) do
    Logger.debug("Handling unmute command.")

    {:ok, state} = Voice.current_state(context.guild_id)

    channel_id = state["channel_id"]
    guild_id = state["guild_id"]
    self_deaf = state["self_deaf"]
    self_mute = false

    Event.update_voice_state(channel_id, guild_id, self_deaf, self_mute)

    {:punctual, ":speaker: **Doorknob has been unmuted.**"}
  end

  defp handle(%{name: "uptime"}) do
    Logger.debug("Handling uptime command.")

    {uptime, _} = :erlang.statistics(:wall_clock)

    {:punctual, ":clock5: **Doorknob has been online for #{uptime / 1000} seconds.**"}
  end

  defp handle(%{name: name}) do
    Logger.warning("Handling unimplemented command: '#{name}'.")

    {:punctual, ":warning: **Doorknob can't handle this command yet.**"}
  end
end
