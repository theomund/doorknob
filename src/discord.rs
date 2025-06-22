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

use std::{
    env,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::Instant,
};

use anyhow::Error;
use dashmap::DashMap;
use poise::{Command, Framework, FrameworkOptions, async_trait};
use serenity::{Client, all::GatewayIntents};
use songbird::{
    Call, CoreEvent, Event, EventContext, EventHandler, SerenityInit, Songbird,
    model::{id::UserId, payload::Speaking},
};
use tokio::sync::Mutex;
use tracing::{info, warn};

struct Data {
    start_time: Instant,
}

type Context<'a> = poise::Context<'a, Data, Error>;

#[derive(Clone)]
struct Receiver {
    inner: Arc<InnerReceiver>,
}

struct InnerReceiver {
    last_tick_was_empty: AtomicBool,
    known_ssrcs: DashMap<u32, UserId>,
}

impl Receiver {
    pub fn new() -> Self {
        Self {
            inner: Arc::new(InnerReceiver {
                last_tick_was_empty: AtomicBool::default(),
                known_ssrcs: DashMap::new(),
            }),
        }
    }
}

#[async_trait]
impl EventHandler for Receiver {
    async fn act(&self, ctx: &EventContext<'_>) -> Option<Event> {
        match ctx {
            EventContext::ClientDisconnect(_) => {
                info!("Received client disconnect event.");
            }
            EventContext::RtcpPacket(_) => {
                info!("Received RTCP packet event.");
            }
            EventContext::RtpPacket(_) => {
                info!("Received RTP packet event.");
            }
            EventContext::SpeakingStateUpdate(Speaking { ssrc, user_id, .. }) => {
                info!("Received speaking state update event.");

                if let Some(user) = user_id {
                    self.inner.known_ssrcs.insert(*ssrc, *user);
                }
            }
            EventContext::VoiceTick(tick) => {
                let speaking = tick.speaking.len();
                let total_participants = speaking + tick.silent.len();
                let last_tick_was_empty = self.inner.last_tick_was_empty.load(Ordering::SeqCst);

                if speaking == 0 && !last_tick_was_empty {
                    info!("Received voice tick with no speakers.");

                    self.inner.last_tick_was_empty.store(true, Ordering::SeqCst);
                } else if speaking != 0 {
                    info!("Received voice tick with {speaking}/{total_participants} speakers.");

                    self.inner
                        .last_tick_was_empty
                        .store(false, Ordering::SeqCst);
                }
            }
            _ => {
                warn!("Received unexpected event.");
            }
        }

        None
    }
}

/// Deafen the bot.
#[poise::command(slash_command)]
async fn deafen(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling deafen command.");

    let Some(handler_lock) = handler(ctx).await else {
        ctx.reply(":x: **Doorknob isn't in a voice call.**").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_deaf() {
        ctx.reply(":x: **Doorknob is already deafened.**").await?;
    } else {
        handler.deafen(true).await?;

        ctx.reply(":ear_with_hearing_aid: **Doorknob is now deafened.**")
            .await?;
    }

    Ok(())
}

/// Make the bot join the call.
#[poise::command(slash_command)]
async fn join(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling join command.");

    let (guild_id, channel_id) = {
        let guild = ctx.guild().unwrap();

        let guild_id = guild.id;

        let author_id = &ctx.author().id;

        let channel_id = guild
            .voice_states
            .get(author_id)
            .and_then(|voice_state| voice_state.channel_id);

        (guild_id, channel_id)
    };

    let Some(channel) = channel_id else {
        ctx.reply(":x: **Doorknob couldn't find your voice call.**")
            .await?;

        return Ok(());
    };

    let manager = manager(ctx).await;

    {
        let handler_lock = manager.get_or_insert(guild_id);
        let mut handler = handler_lock.lock().await;

        let receiver = Receiver::new();

        handler.add_global_event(CoreEvent::ClientDisconnect.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtcpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::SpeakingStateUpdate.into(), receiver.clone());
        handler.add_global_event(CoreEvent::VoiceTick.into(), receiver);
    }

    if manager.join(guild_id, channel).await.is_ok() {
        ctx.reply(":wave: **Doorknob has joined the call.**")
            .await?;
    } else {
        manager.remove(guild_id).await?;
    }

    Ok(())
}

/// Make the bot leave the call.
#[poise::command(slash_command)]
async fn leave(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling leave command.");

    let manager = manager(ctx).await;

    let guild_id = ctx.guild_id().unwrap();
    let has_handler = manager.get(guild_id).is_some();

    if has_handler {
        manager.remove(guild_id).await?;
        ctx.reply(":door: **Doorknob has left the call.**").await?;
    } else {
        ctx.reply(":x: **Doorknob isn't in a voice call.**").await?;
    }

    Ok(())
}

/// Mute the bot.
#[poise::command(slash_command)]
async fn mute(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling mute command.");

    let Some(handler_lock) = handler(ctx).await else {
        ctx.reply(":x: **Doorknob isn't in a voice call.**").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_mute() {
        ctx.reply(":x: **Doorknob is already muted.**").await?;
    } else {
        handler.mute(true).await?;

        ctx.reply(":mute: **Doorknob is now muted.**").await?;
    }

    Ok(())
}

/// Receive a simple diagnostic response.
#[poise::command(slash_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling ping command.");

    ctx.reply(":white_check_mark: **Doorknob is online.**")
        .await?;

    Ok(())
}

/// Undeafen the bot.
#[poise::command(slash_command)]
async fn undeafen(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling undeafen command.");

    let Some(handler_lock) = handler(ctx).await else {
        ctx.reply(":x: **Doorknob isn't in a voice call.**").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_deaf() {
        handler.deafen(false).await?;

        ctx.reply(":ear: **Doorknob is now undeafened.**").await?;
    } else {
        ctx.reply(":x: **Doorknob is already undeafened.**").await?;
    }

    Ok(())
}

/// Unmute the bot.
#[poise::command(slash_command)]
async fn unmute(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling unmute command.");

    let Some(handler_lock) = handler(ctx).await else {
        ctx.reply(":x: **Doorknob isn't in a voice call.**").await?;

        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_mute() {
        handler.mute(false).await?;

        ctx.reply(":speaker: **Doorknob is now unmuted.**").await?;
    } else {
        ctx.reply(":x: **Doorknob is already unmuted.**").await?;
    }

    Ok(())
}

/// Retrieve the bot's uptime.
#[poise::command(slash_command)]
async fn uptime(ctx: Context<'_>) -> Result<(), Error> {
    info!("Handling uptime command.");

    let elapsed = ctx.data().start_time.elapsed().as_secs();
    let message = format!(":clock5: **Doorknob has been online for {elapsed} seconds.**");

    ctx.reply(message).await?;

    Ok(())
}

async fn handler(ctx: Context<'_>) -> Option<Arc<Mutex<Call>>> {
    let manager = manager(ctx).await;
    let guild_id = ctx.guild_id().unwrap();

    manager.get(guild_id)
}

async fn manager(ctx: Context<'_>) -> Arc<Songbird> {
    let context = ctx.serenity_context();

    songbird::get(context).await.unwrap().clone()
}

pub async fn init() -> Result<(), Error> {
    let token = env::var("DISCORD_TOKEN")?;

    let intents = GatewayIntents::non_privileged() | GatewayIntents::MESSAGE_CONTENT;

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
        .register_songbird()
        .await?;

    client.start().await?;

    Ok(())
}
