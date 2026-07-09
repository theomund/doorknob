package main

import "core:log"
import "discord"

main :: proc() {
	context.logger = log.create_console_logger()
	defer log.destroy_console_logger(context.logger)

	if err := discord.run(); err != nil {
		log.error("Encountered error:", err)
	}
}
