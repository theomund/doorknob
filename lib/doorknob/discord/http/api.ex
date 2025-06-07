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

defmodule Doorknob.Discord.HTTP.API do
  @moduledoc """
  Functions for the Discord HTTP API.
  """

  @url "https://discord.com/api/v10"

  def headers(state) do
    [
      {"authorization", "Bot #{state.token}"},
      {"content-type", "application/json"},
      {"user-agent", "Doorknob (https://github.com/theomund/doorknob, 0.1.0)"}
    ]
  end

  def host() do
    uri = uri()
    String.to_charlist(uri.host)
  end

  def path(subpath) do
    uri = uri()
    String.to_charlist(uri.path <> subpath)
  end

  def port() do
    443
  end

  defp uri() do
    URI.parse(@url)
  end
end
