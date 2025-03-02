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
use std::sync::LazyLock;

use async_openai::Client;
use async_openai::config::OpenAIConfig;
use async_openai::types::{
    ChatCompletionRequestMessage, ChatCompletionRequestSystemMessageArgs,
    ChatCompletionRequestUserMessageArgs, CreateChatCompletionRequestArgs, CreateImageRequestArgs,
    ImageModel, ImageResponseFormat, ImageSize,
};
use tokio::sync::Mutex;

use crate::discord::Error;

pub struct Session {
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

    fn append(&mut self, content: String) -> Result<(), Error> {
        let message = ChatCompletionRequestUserMessageArgs::default()
            .content(content)
            .build()?;

        self.context.push(message.into());

        Ok(())
    }

    pub async fn chat(&mut self, prompt: String) -> Result<String, Error> {
        self.append(prompt)?;

        let request = CreateChatCompletionRequestArgs::default()
            .max_completion_tokens(512u32)
            .model("gpt-4o")
            .messages(self.context.clone())
            .build()?;

        let response = self.client.chat().create(request).await?;

        let choice = response.choices.first().expect("Failed to retrieve choice");

        let message = choice
            .message
            .content
            .clone()
            .expect("Failed to retrieve message");

        Ok(message)
    }

    pub async fn image(&self, prompt: String) -> Result<String, Error> {
        let request = CreateImageRequestArgs::default()
            .model(ImageModel::DallE3)
            .prompt(prompt)
            .n(1)
            .response_format(ImageResponseFormat::Url)
            .size(ImageSize::S1024x1024)
            .user("Doorknob")
            .build()?;

        let response = self.client.images().create(request).await?;

        let paths = response.save("./target/data").await?;

        let path = paths
            .first()
            .expect("Failed to retrieve image path")
            .display()
            .to_string();

        Ok(path)
    }
}

pub static SESSION: LazyLock<Mutex<Session>> = LazyLock::new(|| Mutex::new(Session::new()));
