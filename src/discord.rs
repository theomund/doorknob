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

use serenity::async_trait;
use serenity::model::channel::Message;
use serenity::model::gateway::Ready;
use serenity::prelude::{Client, Context, EventHandler, GatewayIntents};
use serenity::{Error, Result};
use tracing::{error, info};

struct Handler;

#[async_trait]
impl EventHandler for Handler {
    async fn message(&self, ctx: Context, msg: Message) {
        if let Err(why) = self.parse(ctx, msg).await {
            error!("Failed to parse message: {why:?}");
        }
    }

    async fn ready(&self, _: Context, ready: Ready) {
        info!("{} is connected!", ready.user.name);
    }
}

impl Handler {
    async fn parse(&self, ctx: Context, msg: Message) -> Result<(), Error> {
        let author = msg.author.display_name();

        match msg.content.as_str() {
            "!join" => {
                info!("{author} invoked the join command.");
                msg.channel_id
                    .say(&ctx.http, "Joining voice channel.")
                    .await?;
            }
            "!leave" => {
                info!("{author} invoked the leave command.");
                msg.channel_id
                    .say(&ctx.http, "Leaving voice channel.")
                    .await?;
            }
            "!ping" => {
                info!("{author} invoked the ping command.");
                msg.channel_id.say(&ctx.http, "Pong!").await?;
            }
            _ => {}
        }

        Ok(())
    }
}

pub async fn init() {
    let token = env::var("DISCORD_TOKEN").expect("Discord token is invalid");

    let intents = GatewayIntents::GUILD_MESSAGES
        | GatewayIntents::DIRECT_MESSAGES
        | GatewayIntents::MESSAGE_CONTENT;

    let mut client = Client::builder(token, intents)
        .event_handler(Handler)
        .await
        .expect("Failed to create client");

    if let Err(why) = client.start().await {
        error!("Client error: {why:?}");
    }
}
