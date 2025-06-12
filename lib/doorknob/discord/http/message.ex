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

defmodule Doorknob.Discord.HTTP.Message do
  @moduledoc """
  Functions for handling messages.
  """

  alias Doorknob.Discord.HTTP.API
  alias Doorknob.Discord.HTTP.Listener

  require Logger

  def create(channel_id, content) do
    path = API.path("/channels/#{channel_id}/messages")
    body = %{content: content}

    Logger.debug("Created message: #{body}.")

    Listener.post(path, body)
  end
end
