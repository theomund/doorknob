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

defmodule Doorknob.OpenAI.Image do
  @moduledoc """
  Functions for handling images.
  """

  alias Doorknob.OpenAI.API
  alias Doorknob.OpenAI.Listener

  require Logger

  def create(prompt) do
    path = API.path("/images/generations")

    body =
      JSON.encode!(%{
        model: "dall-e-3",
        prompt: prompt
      })

    Logger.debug("Created image request: #{body}.")

    response = Listener.post(path, body)

    Logger.debug("Received image response: #{inspect(response)}.")

    url = get_in(response, ["data", Access.at(0), "url"])

    {:ok, url}
  end
end
