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

  alias Doorknob.Discord.HTTP.API
  alias Doorknob.Discord.HTTP.Command
  alias Doorknob.Discord.HTTP.Listener

  require Logger

  def respond(id, name, token) do
    path = API.path("/interactions/#{id}/#{token}/callback")

    content = Command.handle(name)

    body = JSON.encode!(%{type: 4, data: %{content: content}})

    Logger.debug("Sending interaction response: #{body}.")

    GenServer.cast(Listener, {:post, path, body})
  end
end
