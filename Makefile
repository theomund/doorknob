# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

ifneq (,$(wildcard ./.env))
	include .env
	export
endif

.PHONY: all build clean format lint run test

all: lint test build

build:
	odin build .

clean:
	git clean -fdxe ".env"

format:
	odinfmt . -w

lint:
	hadolint .devcontainer/Dockerfile
	odin check . -strict-style -vet
	yamllint .github/workflows/linux.yml

run:
	odin run .

test:
	odin test .
