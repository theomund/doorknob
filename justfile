# Doorknob - Artificial intelligence companion written in Rust.
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

# Build the project.
build:
    @echo "To be implemented."

# Clean the project.
clean:
    git clean -fdx

# Run the project linters.
lint: vale yamllint

# Run the test suite.
test:
    @echo "To be implemented."

# Run the prose linter.
vale:
    vale sync
    vale README.md

# Run the YAML linter.
yamllint:
    yamllint .github/workflows
