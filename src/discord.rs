// Doorknob - Artificial intelligence companion written in Rust.
// Copyright (C) 2025 Theomund
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

use std::env;

use anyhow::Error;
use poise::{Command, Framework, FrameworkOptions};
use serenity::{Client, all::GatewayIntents};
use tracing::{error, info};

struct Data {}
type Context<'a> = poise::Context<'a, Data, Error>;

#[poise::command(slash_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling ping command");

    ctx.reply(":white_check_mark: **Doorknob is online.**").await?;

    Ok(())
}

pub async fn init() {
    let token = env::var("DISCORD_TOKEN").expect("Expected a token to be specified");

    let intents = GatewayIntents::GUILD_MESSAGES
        | GatewayIntents::DIRECT_MESSAGES
        | GatewayIntents::MESSAGE_CONTENT;

    let options = FrameworkOptions {
        commands: vec![ping()],
        ..Default::default()
    };

    let framework = Framework::builder()
        .options(options)
        .setup(|ctx, ready, framework| {
            Box::pin(async move {
                let global_commands: Vec<Command<Context, Error>> = Vec::new();

                poise::builtins::register_globally(ctx, &global_commands).await?;

                let guild_commands = &framework.options().commands;

                for guild in &ready.guilds {
                    poise::builtins::register_in_guild(ctx, guild_commands, guild.id).await?;
                }

                let data = Data {};

                Ok(data)
            })
        })
        .build();

    let mut client = Client::builder(token, intents)
        .framework(framework)
        .await
        .expect("Failed to create client");

    if let Err(why) = client.start().await {
        error!("Failed to start client: {why:?}");
    }
}
