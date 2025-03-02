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
use std::sync::{LazyLock, Mutex};

use async_openai::Client;
use async_openai::config::OpenAIConfig;
use async_openai::types::{
    ChatCompletionRequestMessage, ChatCompletionRequestSystemMessageArgs,
    ChatCompletionRequestUserMessageArgs, CreateChatCompletionRequestArgs,
};

use crate::discord::Error;

struct Session {
    client: Client<OpenAIConfig>,
    context: Vec<ChatCompletionRequestMessage>,
}

impl Session {
    pub fn new() -> Self {
        let client = Client::new();

        let prompt = env::var("PROMPT").expect("Failed to retrieve system prompt");

        let context: Vec<ChatCompletionRequestMessage> = vec![
            ChatCompletionRequestSystemMessageArgs::default()
                .content(prompt)
                .build()
                .expect("Failed to build system message")
                .into(),
        ];

        Self { client, context }
    }

    pub fn append(&mut self, content: &str) -> Result<(), Error> {
        let message = ChatCompletionRequestUserMessageArgs::default()
            .content(content)
            .build()?;

        self.context.push(message.into());

        Ok(())
    }

    pub fn client(&self) -> &Client<OpenAIConfig> {
        &self.client
    }

    pub fn context(&self) -> &Vec<ChatCompletionRequestMessage> {
        &self.context
    }
}

static SESSION: LazyLock<Mutex<Session>> = LazyLock::new(|| Mutex::new(Session::new()));

pub async fn chat(prompt: &str) -> Result<String, Error> {
    let (client, context) = {
        let mut session = SESSION.lock().expect("Failed to get lock");
        session.append(prompt)?;

        let client = session.client().clone();
        let context = session.context().clone();

        (client, context)
    };

    let request = CreateChatCompletionRequestArgs::default()
        .max_completion_tokens(512u32)
        .model("gpt-4o")
        .messages(context)
        .build()?;

    let response = client.chat().create(request).await?;

    let choice = response.choices.first().expect("Failed to retrieve choice");

    let message = choice
        .message
        .content
        .clone()
        .expect("Failed to retrieve message");

    Ok(message)
}
