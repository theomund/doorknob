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

defmodule Doorknob.Discord.HTTP.Command do
  @moduledoc """
  Functions for handling commands.
  """

  alias Doorknob.Discord.HTTP.API
  alias Doorknob.Discord.HTTP.Listener

  require Logger

  def register(application_id, guilds) do
    register_global(application_id)

    Enum.each(guilds, fn guild -> register_guild(application_id, guild["id"]) end)
  end

  defp register_global(application_id) do
    path = API.path("/applications/#{application_id}/commands")
    body = JSON.encode!([])

    Logger.debug("Registering global commands: #{body}.")

    Listener.put(path, body)
  end

  defp register_guild(application_id, guild_id) do
    path = API.path("/applications/#{application_id}/guilds/#{guild_id}/commands")

    chat = %{
      name: "chat",
      description: "Chat with the bot.",
      options: [%{name: "message", description: "The message to send.", required: true, type: 3}]
    }

    deafen = %{name: "deafen", description: "Deafen the bot."}

    image = %{
      name: "image",
      description: "Generate an image.",
      options: [%{name: "prompt", description: "The prompt to send.", required: true, type: 3}]
    }

    join = %{name: "join", description: "Force the bot to join the call."}
    leave = %{name: "leave", description: "Force the bot to leave the call."}
    mute = %{name: "mute", description: "Mute the bot."}
    ping = %{name: "ping", description: "Receive a simple diagnostic response."}
    undeafen = %{name: "undeafen", description: "Undeafen the bot."}
    unmute = %{name: "unmute", description: "Unmute the bot."}
    uptime = %{name: "uptime", description: "Receive the uptime of the bot."}

    commands = [chat, deafen, image, join, leave, mute, ping, undeafen, unmute, uptime]

    body = JSON.encode!(commands)

    Logger.debug("Registering guild commands: #{body}")

    Listener.put(path, body)
  end
end
