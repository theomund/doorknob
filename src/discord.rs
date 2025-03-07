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
use poise::{Framework, FrameworkOptions, builtins};
use serenity::all::{Client, GatewayIntents};
use tracing::info;

struct Data;
type Context<'a> = poise::Context<'a, Data, Error>;

#[poise::command(slash_command)]
async fn chat(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now responding.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn deafen(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now deafened.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn image(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now generating an image.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn join(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob has joined the voice call.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn leave(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob has left the voice call.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn mute(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now muted.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is online.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn speech(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now generating speech.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn transcribe(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now transcribing speech.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn undeafen(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now undeafened.*").await?;
    Ok(())
}

#[poise::command(slash_command)]
async fn unmute(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is now unmuted.*").await?;
    Ok(())
}

pub async fn init() -> Result<(), Error> {
    info!("Starting the Discord module.");

    let options = FrameworkOptions {
        commands: vec![
            chat(),
            deafen(),
            image(),
            join(),
            leave(),
            mute(),
            ping(),
            speech(),
            transcribe(),
            undeafen(),
            unmute(),
        ],
        post_command: |ctx| {
            Box::pin(async move {
                info!(
                    "Executed command '{}' from {}.",
                    ctx.command().qualified_name,
                    ctx.author().display_name()
                );
            })
        },
        pre_command: |ctx| {
            Box::pin(async move {
                info!(
                    "Executing command '{}' from {}.",
                    ctx.command().qualified_name,
                    ctx.author().display_name()
                );
            })
        },
        ..Default::default()
    };

    let framework = Framework::builder()
        .setup(move |ctx, ready, framework| {
            Box::pin(async move {
                info!("Logged in as {}.", ready.user.name);
                builtins::register_globally(ctx, &framework.options().commands).await?;
                Ok(Data {})
            })
        })
        .options(options)
        .build();

    let token = env::var("DISCORD_TOKEN")?;
    let intents = GatewayIntents::non_privileged() | GatewayIntents::MESSAGE_CONTENT;

    let mut client = Client::builder(&token, intents)
        .framework(framework)
        .await?;

    client.start().await?;

    Ok(())
}
