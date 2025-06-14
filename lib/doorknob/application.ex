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

defmodule Doorknob.Application do
  @moduledoc """
  The main application module.
  """

  alias Doorknob.Discord.Gateway
  alias Doorknob.Discord.HTTP
  alias Doorknob.OpenAI

  require Logger

  use Application

  def start(_type, _args) do
    Logger.info("Starting the application.")

    key = Application.get_env(:doorknob, :key)
    prompt = Application.get_env(:doorknob, :prompt)
    token = Application.get_env(:doorknob, :token)

    children = [
      {Gateway.Listener, %{token: token}},
      {HTTP.Listener, %{token: token}},
      {OpenAI.Listener, %{key: key, prompt: prompt}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
