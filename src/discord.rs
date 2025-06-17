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

use std::{env, time::Instant};

use anyhow::Error;
use poise::{Command, Framework, FrameworkOptions};
use serenity::{Client, all::GatewayIntents};
use tracing::{error, info};

struct Data {
    start_time: Instant,
}

type Context<'a> = poise::Context<'a, Data, Error>;

/// Deafen the bot.
#[poise::command(slash_command)]
async fn deafen(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling deafen command");

    ctx.reply(":ear_with_hearing_aid: **Doorknob is now deafened.**")
        .await?;

    Ok(())
}

/// Make the bot join the call.
#[poise::command(slash_command)]
async fn join(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling join command");

    ctx.reply(":wave: **Doorknob has joined the call.**")
        .await?;

    Ok(())
}

/// Make the bot leave the call.
#[poise::command(slash_command)]
async fn leave(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling leave command");

    ctx.reply(":door: **Doorknob has left the call.**").await?;

    Ok(())
}

/// Mute the bot.
#[poise::command(slash_command)]
async fn mute(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling mute command");

    ctx.reply(":mute: **Doorknob is now muted.**").await?;

    Ok(())
}

/// Receive a simple diagnostic response.
#[poise::command(slash_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling ping command");

    ctx.reply(":white_check_mark: **Doorknob is online.**")
        .await?;

    Ok(())
}

/// Undeafen the bot.
#[poise::command(slash_command)]
async fn undeafen(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling undeafen command");

    ctx.reply(":ear: **Doorknob is now undeafened.**").await?;

    Ok(())
}

/// Unmute the bot.
#[poise::command(slash_command)]
async fn unmute(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling unmute command");

    ctx.reply(":speaker: **Doorknob is now unmuted.**").await?;

    Ok(())
}

/// Retrieve the bot's uptime.
#[poise::command(slash_command)]
async fn uptime(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling uptime command");

    let elapsed = ctx.data().start_time.elapsed().as_secs();
    let message = format!(":clock5: **Doorknob has been online for {elapsed} seconds.**");

    ctx.reply(message).await?;

    Ok(())
}

pub async fn init() {
    let token = env::var("DISCORD_TOKEN").expect("Expected a token to be specified");

    let intents = GatewayIntents::GUILD_MESSAGES
        | GatewayIntents::DIRECT_MESSAGES
        | GatewayIntents::MESSAGE_CONTENT;

    let options = FrameworkOptions {
        commands: vec![
            deafen(),
            join(),
            leave(),
            mute(),
            ping(),
            undeafen(),
            unmute(),
            uptime(),
        ],
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

                let start_time = Instant::now();
                let data = Data { start_time };

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
