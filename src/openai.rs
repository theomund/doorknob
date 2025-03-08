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

use std::{env, path::PathBuf, sync::LazyLock};

use anyhow::Error;
use async_openai::{
    Client,
    config::OpenAIConfig,
    types::{
        AudioResponseFormat, ChatCompletionRequestAssistantMessageArgs,
        ChatCompletionRequestDeveloperMessageArgs, ChatCompletionRequestMessage,
        ChatCompletionRequestMessageContentPartImageArgs,
        ChatCompletionRequestMessageContentPartTextArgs, ChatCompletionRequestUserMessageArgs,
        CreateChatCompletionRequestArgs, CreateImageRequestArgs, CreateSpeechRequestArgs,
        CreateTranscriptionRequestArgs, ImageDetail, ImageModel, ImageResponseFormat, ImageSize,
        ImageUrlArgs, SpeechModel, SpeechResponseFormat, Voice,
    },
};
use tokio::sync::Mutex;
use tracing::info;

pub struct Session {
    client: Client<OpenAIConfig>,
    context: Vec<ChatCompletionRequestMessage>,
}

impl Session {
    pub fn new() -> Result<Self, Error> {
        let client = Client::new();

        let prompt = env::var("PROMPT")?;

        let developer = ChatCompletionRequestDeveloperMessageArgs::default()
            .content(prompt)
            .build()?;

        let context = vec![developer.into()];

        Ok(Self { client, context })
    }

    fn append_message(&mut self, content: String, user: bool) -> Result<(), Error> {
        let message = if user {
            ChatCompletionRequestUserMessageArgs::default()
                .content(content)
                .build()?
                .into()
        } else {
            ChatCompletionRequestAssistantMessageArgs::default()
                .content(content)
                .build()?
                .into()
        };

        self.context.push(message);

        Ok(())
    }

    fn append_image(&mut self, url: String) -> Result<(), Error> {
        let message = ChatCompletionRequestUserMessageArgs::default()
            .content(vec![
                ChatCompletionRequestMessageContentPartTextArgs::default()
                    .text("What is this image?")
                    .build()?
                    .into(),
                ChatCompletionRequestMessageContentPartImageArgs::default()
                    .image_url(
                        ImageUrlArgs::default()
                            .url(url)
                            .detail(ImageDetail::High)
                            .build()?,
                    )
                    .build()?
                    .into(),
            ])
            .build()?
            .into();

        self.context.push(message);

        Ok(())
    }

    pub async fn chat(&mut self, message: String) -> Result<String, Error> {
        info!("Received chat completion request: '{message}'.");

        self.append_message(message, true)?;

        let request = CreateChatCompletionRequestArgs::default()
            .max_tokens(512u32)
            .model("gpt-4o")
            .messages(self.context.clone())
            .build()?;

        let response = self.client.chat().create(request).await?;
        let choice = response.choices.first().unwrap();
        let content = choice.message.content.clone().unwrap();

        self.append_message(content.clone(), false)?;

        info!("Returning chat completion response: '{content}'.");

        Ok(content)
    }

    pub async fn image(&self, message: String) -> Result<PathBuf, Error> {
        info!("Received image generation request: '{message}'.");

        let request = CreateImageRequestArgs::default()
            .model(ImageModel::DallE3)
            .n(1)
            .prompt(message)
            .response_format(ImageResponseFormat::Url)
            .size(ImageSize::S1024x1024)
            .user("doorknob")
            .build()?;

        let response = self.client.images().create(request).await?;
        let paths = response.save("./target/data").await?;
        let path = paths.first().unwrap().clone();

        info!("Returning image generation response: '{}'.", path.display());

        Ok(path)
    }

    pub async fn speech(&self, message: String) -> Result<PathBuf, Error> {
        info!("Received speech generation request: '{message}'.");

        let request = CreateSpeechRequestArgs::default()
            .input(message)
            .model(SpeechModel::Tts1)
            .response_format(SpeechResponseFormat::Wav)
            .voice(Voice::Fable)
            .build()?;

        let response = self.client.audio().speech(request).await?;
        let path = PathBuf::from("./target/data/speech.wav");

        response.save(path.clone()).await?;

        info!(
            "Returning speech generation response: '{}'.",
            path.display()
        );

        Ok(path)
    }

    pub async fn transcribe(&self, path: PathBuf) -> Result<String, Error> {
        info!("Received transcription request.");

        let request = CreateTranscriptionRequestArgs::default()
            .file(path)
            .model("whisper-1")
            .response_format(AudioResponseFormat::Json)
            .build()?;

        let response = self.client.audio().transcribe(request).await?;
        let text = response.text;

        info!("Returning transcription response: '{text}'.");

        Ok(text)
    }

    pub async fn vision(&mut self, url: String) -> Result<String, Error> {
        info!("Received vision request.");

        self.append_image(url)?;

        let request = CreateChatCompletionRequestArgs::default()
            .max_tokens(512u32)
            .messages(self.context.clone())
            .model("gpt-4o")
            .build()?;

        let response = self.client.chat().create(request).await?;
        let choice = response.choices.first().unwrap();
        let text = choice.message.content.clone().unwrap();

        self.append_message(text.clone(), true)?;

        info!("Returning vision response: '{}'.", text);

        Ok(text)
    }
}

pub static SESSION: LazyLock<Mutex<Session>> =
    LazyLock::new(|| Mutex::new(Session::new().unwrap()));
