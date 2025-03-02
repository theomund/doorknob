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

use poise::{CreateReply, Framework, FrameworkOptions, PrefixFrameworkOptions};
use serenity::all::{Client, CreateAttachment, GatewayIntents, async_trait};
use songbird::{Event, EventContext, EventHandler, SerenityInit, TrackEvent};
use tracing::{error, info};

use crate::openai::SESSION;

struct Data;

pub type Error = Box<dyn std::error::Error + Send + Sync>;

type Context<'a> = poise::Context<'a, Data, Error>;

struct TrackEventNotifier;

#[async_trait]
impl EventHandler for TrackEventNotifier {
    async fn act(&self, ctx: &EventContext<'_>) -> Option<Event> {
        if let EventContext::Track(track_list) = ctx {
            for (state, handle) in *track_list {
                error!(
                    "Track {:?} encountered an error {:?}",
                    handle.uuid(),
                    state.playing
                );
            }
        }

        None
    }
}

#[poise::command(slash_command, prefix_command)]
async fn chat(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let mut session = SESSION.lock().await;
    let response = session.chat(message).await?;

    ctx.reply(response).await?;

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn deafen(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().expect("Failed to retrieve guild ID");

    let manager = songbird::get(ctx.serenity_context())
        .await
        .expect("Failed to retrieve manager")
        .clone();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("I'm not in a voice channel.").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_deaf() {
        ctx.reply("I'm already deafened.").await?;
    } else {
        handler.deafen(true).await?;

        ctx.reply("I'm now deafened.").await?;
    }

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn image(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let session = SESSION.lock().await;
    let response = session.image(message).await?;

    let attachment = CreateAttachment::path(response).await?;
    let reply = CreateReply::default().attachment(attachment);

    ctx.send(reply).await?;

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn join(ctx: Context<'_>) -> Result<(), Error> {
    let (channel_id, guild_id) = {
        let guild = ctx.guild().expect("Failed to retrieve guild");
        let channel_id = guild
            .voice_states
            .get(&ctx.author().id)
            .and_then(|voice_state| voice_state.channel_id);
        let guild_id = guild.id;

        (channel_id, guild_id)
    };

    let Some(connect_to) = channel_id else {
        ctx.reply("You're not in a voice channel.").await?;

        return Ok(());
    };

    let manager = songbird::get(ctx.serenity_context())
        .await
        .expect("Failed to retrieve manager");

    if let Ok(handler_lock) = manager.join(guild_id, connect_to).await {
        let mut handler = handler_lock.lock().await;

        handler.add_global_event(TrackEvent::Error.into(), TrackEventNotifier);

        ctx.reply("I've joined the voice channel.").await?;
    }

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn leave(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().expect("Failed to retrieve guild ID");

    let manager = songbird::get(ctx.serenity_context())
        .await
        .expect("Failed to retrieve manager")
        .clone();

    let has_handler = manager.get(guild_id).is_some();

    if has_handler {
        manager.remove(guild_id).await?;

        ctx.reply("I've left the voice channel.").await?;
    } else {
        ctx.reply("I'm not in a voice channel.").await?;
    }

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn mute(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().expect("Failed to retrieve guild ID");

    let manager = songbird::get(ctx.serenity_context())
        .await
        .expect("Failed to retrieve manager")
        .clone();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("I'm not in a voice channel.").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_mute() {
        ctx.reply("I'm already muted.").await?;
    } else {
        handler.mute(true).await?;

        ctx.reply("I'm now muted.").await?;
    }

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("Pong!").await?;

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn undeafen(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().expect("Failed to retrieve guild ID");

    let manager = songbird::get(ctx.serenity_context())
        .await
        .expect("Failed to retrieve manager")
        .clone();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("I'm not in a voice channel.").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_deaf() {
        handler.deafen(false).await?;

        ctx.reply("I'm now undeafened.").await?;
    } else {
        ctx.reply("I'm already deafened.").await?;
    }

    Ok(())
}

#[poise::command(slash_command, prefix_command)]
async fn unmute(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().expect("Failed to retrieve guild ID");

    let manager = songbird::get(ctx.serenity_context())
        .await
        .expect("Failed to retrieve manager")
        .clone();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("I'm not in a voice channel.").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_mute() {
        handler.mute(false).await?;

        ctx.reply("I'm now unmuted.").await?;
    } else {
        ctx.reply("I'm already muted.").await?;
    }

    Ok(())
}

pub async fn init() {
    let token = env::var("DISCORD_TOKEN").expect("Discord token is invalid");

    let intents = GatewayIntents::non_privileged() | GatewayIntents::MESSAGE_CONTENT;

    let framework = Framework::builder()
        .options(FrameworkOptions {
            commands: vec![
                chat(),
                deafen(),
                image(),
                join(),
                leave(),
                mute(),
                ping(),
                undeafen(),
                unmute(),
            ],
            post_command: |ctx| {
                Box::pin(async move {
                    info!(
                        "Finished processing {}'s '{}' command.",
                        ctx.author().display_name(),
                        ctx.command().qualified_name
                    );
                })
            },
            pre_command: |ctx| {
                Box::pin(async move {
                    info!(
                        "Started processing {}'s '{}' command.",
                        ctx.author().display_name(),
                        ctx.command().qualified_name
                    );
                })
            },
            prefix_options: PrefixFrameworkOptions {
                prefix: Some("!".into()),
                ..Default::default()
            },
            ..Default::default()
        })
        .setup(|ctx, ready, framework| {
            Box::pin(async move {
                info!("{} has connected.", ready.user.name);

                poise::builtins::register_globally(ctx, &framework.options().commands).await?;

                Ok(Data {})
            })
        })
        .build();

    let mut client = Client::builder(token, intents)
        .framework(framework)
        .register_songbird()
        .await
        .expect("Failed to create client");

    if let Err(why) = client.start().await {
        error!("Client error: {why:?}");
    }
}
