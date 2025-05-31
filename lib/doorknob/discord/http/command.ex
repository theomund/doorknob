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
  Convenience functions for creating Command resource requests.
  """

  alias Doorknob.Discord.HTTP.API
  alias Doorknob.Discord.HTTP.Listener
  alias Doorknob.Discord.HTTP.Message

  def register(application_id) do
    register_global(application_id)
    register_guild(application_id, "1284554342514561175")
  end

  defp register_global(application_id) do
    path = API.path("/applications/#{application_id}/commands")
    body = JSON.encode!([])

    GenServer.cast(Listener, {:put, path, body})
  end

  defp register_guild(application_id, guild_id) do
    path = API.path("/applications/#{application_id}/guilds/#{guild_id}/commands")
    uptime = %{name: "uptime", description: "Get the uptime of the bot."}
    body = JSON.encode!([uptime])

    GenServer.cast(Listener, {:put, path, body})
  end

  def ping(channel_id) do
    Message.create(channel_id, ":white_check_mark: **Doorknob is online.**")
  end

  def uptime(channel_id) do
    {uptime, _} = :erlang.statistics(:wall_clock)

    Message.create(
      channel_id,
      ":clock5: **Doorknob has been online for #{uptime / 1000} seconds.**"
    )
  end
end
