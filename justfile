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

# Run all CI/CD stages.
all: lint test build

# Build the project source code.
build: build-mix

# Build the Elixir source code.
build-mix: setup-mix
    mix compile

# Clean the project source tree.
clean: clean-mix clean-vale

# Clean the Elixir build files.
clean-mix:
    mix clean --deps

# Clean the Vale data files.
clean-vale:
    rm -rf .vale

# Format the project source code.
format: format-mix

# Format the Elixir source code.
format-mix:
    mix format

# Lint the project source code.
lint: lint-credo lint-vale lint-yamllint

# Run the Elixir linter.
lint-credo:
    mix credo

# Run the prose linter.
lint-vale:
    vale sync
    vale README.md

# Run the YAML linter.
lint-yamllint:
    yamllint .github/workflows

# Run the project.
run: run-mix

# Run the Elixir application.
run-mix: setup-mix
    mix run --no-halt

# Setup the project.
setup: setup-mix

# Setup the Elixir dependencies.
setup-mix:
    mix deps.get

# Run the project test suite.
test: test-mix

# Test the Elixir source code.
test-mix: setup-mix
    mix test
