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

defmodule Doorknob.OpenAI.API do
  @moduledoc """
  Functions for the OpenAI API.
  """

  @url "https://api.openai.com/v1"

  def headers(key) do
    %{
      authorization: "Bearer #{key}",
      "content-type": "application/json",
      "user-agent": "Doorknob (https://github.com/theomund/doorknob, 0.1.0)"
    }
  end

  def path(subpath) do
    @url <> subpath
  end

  def timeout do
    30_000
  end
end
