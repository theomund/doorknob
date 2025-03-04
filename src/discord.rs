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
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use dashmap::DashMap;
use poise::{CreateReply, Framework, FrameworkOptions, PrefixFrameworkOptions, builtins};
use serenity::all::{Client, CreateAttachment, GatewayIntents, async_trait};
use songbird::driver::DecodeMode;
use songbird::model::id::UserId;
use songbird::model::payload::{ClientDisconnect, Speaking};
use songbird::packet::Packet;
use songbird::{Config, CoreEvent, Event, EventContext, EventHandler, SerenityInit};
use tracing::{error, info, warn};

use crate::openai::SESSION;

struct Data;
pub type Error = Box<dyn std::error::Error + Send + Sync>;
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
            EventContext::SpeakingStateUpdate(Speaking {
                speaking,
                ssrc,
                user_id,
                ..
            }) => {
                info!(
                    "Speaking state update: user {user_id:?} has SSRC {ssrc:?}, using {speaking:?}."
                );

                if let Some(user) = user_id {
                    self.inner.known_ssrcs.insert(*ssrc, *user);
                }
            }
            EventContext::VoiceTick(tick) => {
                let speaking = tick.speaking.len();
                let total_participants = speaking + tick.silent.len();
                let last_tick_was_empty = self.inner.last_tick_was_empty.load(Ordering::SeqCst);

                if speaking == 0 && !last_tick_was_empty {
                    info!("No speakers.");

                    self.inner.last_tick_was_empty.store(true, Ordering::SeqCst);
                } else if speaking != 0 {
                    self.inner
                        .last_tick_was_empty
                        .store(false, Ordering::SeqCst);

                    info!("Voice tick ({speaking}/{total_participants} live):");

                    for (ssrc, data) in &tick.speaking {
                        let user_id_string = if let Some(id) = self.inner.known_ssrcs.get(ssrc) {
                            format!("{:?}", *id)
                        } else {
                            "?".into()
                        };

                        if let Some(decoded_voice) = data.decoded_voice.as_ref() {
                            let voice_length = decoded_voice.len();

                            let audio_string = format!(
                                "first samples from {voice_length}: {:?}",
                                &decoded_voice[..voice_length.min(5)]
                            );

                            if let Some(packet) = &data.packet {
                                let rtp = packet.rtp();
                                info!(
                                    "\t{ssrc}/{user_id_string}: packet seq {} ts {} -- {audio_string}",
                                    rtp.get_sequence().0,
                                    rtp.get_timestamp().0
                                );
                            } else {
                                warn!("\t{ssrc}/{user_id_string}: Missed packet -- {audio_string}");
                            }
                        } else {
                            warn!("\t{ssrc}/{user_id_string}: Decode disabled.");
                        }
                    }
                }
            }
            EventContext::RtpPacket(packet) => {
                let rtp = packet.rtp();
                info!(
                    "Received voice packet from SSRC {}, sequence {}, timestamp {} -- {}B long",
                    rtp.get_ssrc(),
                    rtp.get_sequence().0,
                    rtp.get_timestamp().0,
                    rtp.payload().len()
                );
            }
            EventContext::RtcpPacket(data) => {
                info!("RTCP packet received: {:?}", data.packet);
            }
            EventContext::ClientDisconnect(ClientDisconnect { user_id, .. }) => {
                info!("Client disconnected: user {:?}", user_id);
            }
            _ => {
                unimplemented!()
            }
        }

        None
    }
}

/// Chat with the bot by providing a message.
#[poise::command(slash_command, prefix_command)]
async fn chat(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let mut session = SESSION.lock().await;
    let response = session.chat(message).await?;

    ctx.reply(response).await?;

    Ok(())
}

/// Deafen the bot within the voice call.
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

/// Display this help menu.
#[poise::command(slash_command, prefix_command)]
async fn help(ctx: Context<'_>, command: Option<String>) -> Result<(), Error> {
    builtins::help(
        ctx,
        command.as_deref(),
        builtins::HelpConfiguration::default(),
    )
    .await?;

    Ok(())
}

/// Generate an image by providing a message.
#[poise::command(slash_command, prefix_command)]
async fn image(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let session = SESSION.lock().await;
    let response = session.image(message).await?;

    let attachment = CreateAttachment::path(response).await?;
    let reply = CreateReply::default().attachment(attachment);

    ctx.send(reply).await?;

    Ok(())
}

/// Have the bot join the voice call.
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

        let receiver = Receiver::new();

        handler.add_global_event(CoreEvent::SpeakingStateUpdate.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtcpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::ClientDisconnect.into(), receiver.clone());
        handler.add_global_event(CoreEvent::VoiceTick.into(), receiver.clone());

        ctx.reply("I've joined the voice channel.").await?;
    }

    Ok(())
}

/// Have the bot leave the voice call.
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

/// Mute the bot within the voice call.
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

/// Provide a simple diagnostic response.
#[poise::command(slash_command, prefix_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("Pong!").await?;

    Ok(())
}

/// Generate speech by providing a message.
#[poise::command(slash_command, prefix_command)]
async fn tts(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let session = SESSION.lock().await;
    let response = session.tts(message).await?;

    let attachment = CreateAttachment::path(response).await?;
    let reply = CreateReply::default().attachment(attachment);

    ctx.send(reply).await?;

    Ok(())
}

/// Undeafen the bot within the voice call.
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

/// Unmute the bot within the voice call.
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

    let config = Config::default().decode_mode(DecodeMode::Decode);

    let framework = Framework::builder()
        .options(FrameworkOptions {
            commands: vec![
                chat(),
                deafen(),
                help(),
                image(),
                join(),
                leave(),
                mute(),
                ping(),
                tts(),
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
        .register_songbird_from_config(config)
        .await
        .expect("Failed to create client");

    if let Err(why) = client.start().await {
        error!("Client error: {why:?}");
    }
}
