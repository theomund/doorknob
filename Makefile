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
	odin check . -vet
	yamllint .github/workflows/linux.yml

run:	
	odin run .

test:
	odin test .
