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
  Convenience functions for handling commands.
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

    GenServer.cast(Listener, {:put, path, body})
  end

  defp register_guild(application_id, guild_id) do
    path = API.path("/applications/#{application_id}/guilds/#{guild_id}/commands")

    ping = %{name: "ping", description: "Get a simple diagnostic response."}
    uptime = %{name: "uptime", description: "Get the uptime of the bot."}
    commands = [ping, uptime]

    body = JSON.encode!(commands)

    Logger.debug("Registering guild commands: #{body}")

    GenServer.cast(Listener, {:put, path, body})
  end

  def ping() do
    Logger.debug("Handling ping command.")

    ":white_check_mark: **Doorknob is online.**"
  end

  def uptime() do
    Logger.debug("Handling uptime command.")

    {uptime, _} = :erlang.statistics(:wall_clock)

    ":clock5: **Doorknob has been online for #{uptime / 1000} seconds.**"
  end
end
