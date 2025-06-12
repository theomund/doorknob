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

defmodule Doorknob.Discord.HTTP.API.Test do
  alias Doorknob.Discord.HTTP.API

  use ExUnit.Case

  test "Headers" do
    token = "foo"

    actual = API.headers(token)

    expected = %{
      authorization: "Bot foo",
      "content-type": "application/json",
      "user-agent": "Doorknob (https://github.com/theomund/doorknob, 0.1.0)"
    }

    assert actual == expected
  end

  test "Path" do
    assert API.path("/foo") == "https://discord.com/api/v10/foo"
  end
end
