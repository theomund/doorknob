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

defmodule Doorknob.OpenAI.Chat do
  @moduledoc """
  Functions for handling chats.
  """

  alias Doorknob.OpenAI.API
  alias Doorknob.OpenAI.Listener

  require Logger

  def create(message) do
    path = API.path("/responses")

    context = Listener.update_context("user", message)
    body = %{input: context, model: "gpt-4.1", store: false}

    Logger.debug("Created chat request: #{inspect(body)}.")

    response = Listener.post(path, body)

    Logger.debug("Received chat response: #{inspect(response)}.")

    text = get_in(response, ["output", Access.at(0), "content", Access.at(0), "text"])

    Listener.update_context("assistant", text)

    {:ok, text}
  end
end
