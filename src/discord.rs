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
    env, fs,
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    vec,
};

use anyhow::Error;
use dashmap::DashMap;
use hound::{SampleFormat, WavSpec, WavWriter};
use poise::{Command, CreateReply, Framework, FrameworkOptions, builtins};
use serenity::all::{Client, CreateAttachment, GatewayIntents, GuildId, async_trait};
use songbird::{
    Config, CoreEvent, Event, EventContext, EventHandler, SerenityInit, Songbird, TrackEvent,
    driver::DecodeMode,
    events::context_data::{RtcpData, RtpData, VoiceTick},
    input::{File, Input},
    model::{
        SpeakingState,
        id::UserId,
        payload::{ClientDisconnect, Speaking},
    },
    packet::Packet,
    tracks::{TrackHandle, TrackState},
};
use tracing::{error, info, warn};

use crate::openai::SESSION;

struct Data;

type Context<'a> = poise::Context<'a, Data, Error>;

#[derive(Clone)]
struct Receiver {
    inner: Arc<InnerReceiver>,
}

struct InnerReceiver {
    guild_id: GuildId,
    last_tick_was_empty: AtomicBool,
    manager: Arc<Songbird>,
    known_ssrcs: DashMap<u32, UserId>,
    spec: WavSpec,
    voice_samples: DashMap<u32, Vec<i16>>,
}

impl Receiver {
    pub fn new(guild_id: GuildId, manager: Arc<Songbird>) -> Self {
        Self {
            inner: Arc::new(InnerReceiver {
                guild_id,
                last_tick_was_empty: AtomicBool::default(),
                known_ssrcs: DashMap::new(),
                manager,
                spec: WavSpec {
                    bits_per_sample: 16,
                    channels: 2,
                    sample_format: SampleFormat::Int,
                    sample_rate: 44100,
                },
                voice_samples: DashMap::new(),
            }),
        }
    }

    fn client_disconnect_handler(user_id: UserId) {
        info!("Client disconnected: user {user_id:?}.");
    }

    fn rtcp_packet_handler(data: &RtcpData) {
        info!("RTCP packet received: {:?}.", data.packet);
    }

    fn rtp_packet_handler(packet: &RtpData) {
        let rtp = packet.rtp();
        info!(
            "Received voice packet from SSRC {}, sequence {}, timestamp {}, -- {}B long.",
            rtp.get_ssrc(),
            rtp.get_sequence().0,
            rtp.get_timestamp().0,
            rtp.payload().len()
        );
    }

    fn speaking_state_update_handler(
        &self,
        speaking: SpeakingState,
        ssrc: u32,
        user_id: Option<&UserId>,
    ) {
        info!("Speaking state update: user {user_id:?} has SSRC {ssrc:?}, using {speaking:?}.");

        if let Some(user) = user_id {
            self.inner.known_ssrcs.insert(ssrc, *user);
            self.inner.voice_samples.insert(ssrc, vec![]);
        }
    }

    fn track_handler(track_list: &&[(&TrackState, &TrackHandle)]) {
        for (state, handle) in *track_list {
            error!(
                "Track {:?} encountered an error: {:?}.",
                handle.uuid(),
                state.playing
            );
        }
    }

    async fn voice_tick_handler(&self, tick: &VoiceTick) -> Result<(), Error> {
        let speaking = tick.speaking.len();
        let total_participants = speaking + tick.silent.len();
        let last_tick_was_empty = self.inner.last_tick_was_empty.load(Ordering::SeqCst);

        if speaking == 0 && !last_tick_was_empty {
            info!("There are currently no speakers.");

            fs::create_dir_all("./target/data")?;

            for mut samples in self.inner.voice_samples.iter_mut() {
                let path = PathBuf::from("./target/data/transcribe.wav");

                let mut writer = WavWriter::create(path.clone(), self.inner.spec)?;

                for sample in samples.iter() {
                    writer.write_sample(*sample)?;
                }

                writer.finalize()?;

                let mut session = SESSION.lock().await;

                let transcription = session.transcribe(path).await?;
                let response = session.chat(transcription).await?;
                let audio = session.speech(response).await?;

                let handler_lock = self.inner.manager.get(self.inner.guild_id).unwrap();
                let mut handler = handler_lock.lock().await;

                let file = File::new(audio);
                let input = Input::from(file);

                handler.play_input(input);

                samples.clear();
            }

            self.inner.last_tick_was_empty.store(true, Ordering::SeqCst);
        } else if speaking != 0 {
            self.inner
                .last_tick_was_empty
                .store(false, Ordering::SeqCst);

            info!("Voice tick ({speaking}/{total_participants} live):");

            for (ssrc, data) in &tick.speaking {
                let user_id = if let Some(id) = self.inner.known_ssrcs.get(ssrc) {
                    format!("{:?}", *id)
                } else {
                    "?".into()
                };

                if let Some(decoded_voice) = data.decoded_voice.as_ref() {
                    if let Some(mut samples) = self.inner.voice_samples.get_mut(ssrc) {
                        samples.extend(decoded_voice);
                    }

                    let voice_length = decoded_voice.len();

                    let audio = format!(
                        "first samples from {voice_length}: {:?}",
                        &decoded_voice[..voice_length.min(5)]
                    );

                    if let Some(packet) = &data.packet {
                        let rtp = packet.rtp();
                        info!(
                            "\t{ssrc}/{user_id}: packet seq {} ts {} -- {audio}",
                            rtp.get_sequence().0,
                            rtp.get_timestamp().0
                        );
                    } else {
                        warn!("\t{ssrc}/{user_id}: Missed packet -- {audio}");
                    }
                } else {
                    warn!("\t{ssrc}/{user_id}: Decode disabled.");
                }
            }
        }

        Ok(())
    }
}

#[async_trait]
impl EventHandler for Receiver {
    async fn act(&self, ctx: &EventContext<'_>) -> Option<Event> {
        match ctx {
            EventContext::ClientDisconnect(ClientDisconnect { user_id, .. }) => {
                Receiver::client_disconnect_handler(*user_id);
            }
            EventContext::RtcpPacket(data) => Receiver::rtcp_packet_handler(data),
            EventContext::RtpPacket(packet) => Receiver::rtp_packet_handler(packet),
            EventContext::SpeakingStateUpdate(Speaking {
                speaking,
                ssrc,
                user_id,
                ..
            }) => self.speaking_state_update_handler(*speaking, *ssrc, user_id.as_ref()),
            EventContext::Track(track_list) => Receiver::track_handler(track_list),
            EventContext::VoiceTick(tick) => self.voice_tick_handler(tick).await.unwrap(),
            _ => unimplemented!(),
        }

        None
    }
}

/// Chat with the bot.
#[poise::command(slash_command)]
async fn chat(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let mut session = SESSION.lock().await;

    ctx.defer().await?;

    let response = session.chat(message).await?;

    ctx.reply(response).await?;

    Ok(())
}

/// Deafen the bot.
#[poise::command(slash_command)]
async fn deafen(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().unwrap();

    let manager = songbird::get(ctx.serenity_context()).await.unwrap();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("*Doorknob is not in a voice call.*").await?;
        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_deaf() {
        ctx.reply("*Doorknob is already deafened.*").await?;
    } else {
        handler.deafen(true).await?;
        ctx.reply("*Doorknob is now deafened.*").await?;
    }

    Ok(())
}

/// Display this help menu.
#[poise::command(slash_command)]
async fn help(
    ctx: Context<'_>,
    #[description = "The command to query for."] command: Option<String>,
) -> Result<(), Error> {
    let config = builtins::HelpConfiguration {
        ..Default::default()
    };

    builtins::help(ctx, command.as_deref(), config).await?;

    Ok(())
}

/// Generate an image.
#[poise::command(slash_command)]
async fn image(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let session = SESSION.lock().await;

    ctx.defer().await?;

    let response = session.image(message).await?;

    let attachment = CreateAttachment::path(response).await?;
    let reply = CreateReply::default().attachment(attachment);

    ctx.send(reply).await?;

    Ok(())
}

/// Inject the bot into the call.
#[poise::command(slash_command)]
async fn join(ctx: Context<'_>) -> Result<(), Error> {
    let (channel_id, guild_id) = {
        let author = &ctx.author().id;
        let guild = ctx.guild().unwrap();
        let channel_id = guild
            .voice_states
            .get(author)
            .and_then(|voice_state| voice_state.channel_id);
        let guild_id = guild.id;

        (channel_id, guild_id)
    };

    let Some(channel) = channel_id else {
        ctx.reply("*Doorknob failed to find the voice call.*")
            .await?;

        return Ok(());
    };

    let manager = songbird::get(ctx.serenity_context()).await.unwrap();

    {
        let handler_lock = manager.get_or_insert(guild_id);
        let mut handler = handler_lock.lock().await;

        let receiver = Receiver::new(guild_id, manager.clone());

        handler.add_global_event(CoreEvent::ClientDisconnect.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtcpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::RtcpPacket.into(), receiver.clone());
        handler.add_global_event(CoreEvent::SpeakingStateUpdate.into(), receiver.clone());
        handler.add_global_event(CoreEvent::VoiceTick.into(), receiver.clone());
        handler.add_global_event(TrackEvent::Error.into(), receiver.clone());
    }

    if manager.join(guild_id, channel).await.is_ok() {
        ctx.reply("*Doorknob has joined the voice call.*").await?;
    } else {
        manager.remove(guild_id).await?;

        ctx.reply("*Doorknob failed to join the voice call.*")
            .await?;
    }

    Ok(())
}

/// Eject the bot from the call.
#[poise::command(slash_command)]
async fn leave(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().unwrap();

    let manager = songbird::get(ctx.serenity_context()).await.unwrap().clone();

    let has_handler = manager.get(guild_id).is_some();

    if has_handler {
        manager.remove(guild_id).await?;
        ctx.reply("*Doorknob has left the voice call.*").await?;
    } else {
        ctx.reply("*Doorknob is not in a voice call.*").await?;
    }

    Ok(())
}

/// Mute the bot.
#[poise::command(slash_command)]
async fn mute(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().unwrap();

    let manager = songbird::get(ctx.serenity_context()).await.unwrap();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("*Doorknob is not in a voice call.*").await?;
        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_mute() {
        ctx.reply("*Doorknob is already muted.*").await?;
    } else {
        handler.mute(true).await?;
        ctx.reply("*Doorknob is now muted.*").await?;
    }

    Ok(())
}

/// Provide a diagnostic response.
#[poise::command(slash_command)]
async fn ping(ctx: Context<'_>) -> Result<(), Error> {
    ctx.reply("*Doorknob is online.*").await?;

    Ok(())
}

/// Transform text into speech.
#[poise::command(slash_command)]
async fn speech(ctx: Context<'_>, message: String) -> Result<(), Error> {
    let session = SESSION.lock().await;

    ctx.defer().await?;

    let response = session.speech(message).await?;

    let attachment = CreateAttachment::path(response).await?;
    let reply = CreateReply::default().attachment(attachment);

    ctx.send(reply).await?;

    Ok(())
}

/// Transform speech into text.
#[poise::command(slash_command)]
async fn transcribe(ctx: Context<'_>) -> Result<(), Error> {
    let session = SESSION.lock().await;

    ctx.defer().await?;

    let path = PathBuf::from("./target/data/speech.wav");
    let response = session.transcribe(path).await?;

    ctx.reply(response).await?;

    Ok(())
}

/// Undeafen the bot.
#[poise::command(slash_command)]
async fn undeafen(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().unwrap();

    let manager = songbird::get(ctx.serenity_context()).await.unwrap();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("*Doorknob is not in a voice call.*").await?;
        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_deaf() {
        handler.deafen(false).await?;
        ctx.reply("*Doorknob is now undeafened.*").await?;
    } else {
        ctx.reply("*Doorknob is already undeafened.*").await?;
    }

    Ok(())
}

/// Unmute the bot.
#[poise::command(slash_command)]
async fn unmute(ctx: Context<'_>) -> Result<(), Error> {
    let guild_id = ctx.guild_id().unwrap();

    let manager = songbird::get(ctx.serenity_context()).await.unwrap();

    let Some(handler_lock) = manager.get(guild_id) else {
        ctx.reply("*Doorknob is not in a voice call.*").await?;
        return Ok(());
    };

    let mut handler = handler_lock.lock().await;

    if handler.is_mute() {
        handler.mute(false).await?;
        ctx.reply("*Doorknob is now unmuted.*").await?;
    } else {
        ctx.reply("*Doorknob is already unmuted.*").await?;
    }

    Ok(())
}

/// Describe image into text.
#[poise::command(slash_command)]
async fn vision(ctx: Context<'_>, url: String) -> Result<(), Error> {
    let mut session = SESSION.lock().await;

    ctx.defer().await?;

    let response = session.vision(url).await?;

    ctx.reply(response).await?;

    Ok(())
}

pub async fn init() -> Result<(), Error> {
    info!("Starting the Discord module.");

    let options = FrameworkOptions {
        commands: vec![
            chat(),
            deafen(),
            help(),
            image(),
            join(),
            leave(),
            mute(),
            ping(),
            speech(),
            transcribe(),
            undeafen(),
            unmute(),
            vision(),
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

                let empty_commands: Vec<Command<Data, Error>> = vec![];

                builtins::register_globally(ctx, &empty_commands).await?;

                let guild_id = {
                    let guild_env = env::var("GUILD_ID")?;
                    let guild_id = guild_env.parse()?;
                    GuildId::new(guild_id)
                };

                builtins::register_in_guild(ctx, &framework.options().commands, guild_id).await?;

                let data = Data {};

                Ok(data)
            })
        })
        .options(options)
        .build();

    let token = env::var("DISCORD_TOKEN")?;
    let intents = GatewayIntents::non_privileged() | GatewayIntents::MESSAGE_CONTENT;
    let config = Config::default().decode_mode(DecodeMode::Decode);

    let mut client = Client::builder(&token, intents)
        .framework(framework)
        .register_songbird_from_config(config)
        .await?;

    client.start().await?;

    Ok(())
}
