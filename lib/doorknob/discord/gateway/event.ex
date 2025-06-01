defmodule Doorknob.Discord.Gateway.Event do
  @moduledoc """
  Convenience functions for handling Gateway API events.
  """

  alias Doorknob.Discord.Gateway.Listener
  alias Doorknob.Discord.HTTP.Command
  alias Doorknob.Discord.HTTP.Interaction

  require Logger

  def handle(
        %{
          "op" => 0,
          "d" => %{"data" => %{"name" => name}, "id" => id, "token" => token},
          "t" => "INTERACTION_CREATE"
        },
        state
      ) do
    Logger.info("Received interaction create event.")

    Interaction.respond(id, name, token)

    state
  end

  def handle(%{"op" => 0, "t" => "MESSAGE_CREATE"}, state) do
    Logger.info("Received message create event.")

    state
  end

  def handle(
        %{
          "op" => 0,
          "d" => %{"application" => %{"id" => application_id}, "guilds" => guilds},
          "t" => "READY"
        },
        state
      ) do
    Logger.info("Received ready event.")

    state = put_in(state.id, application_id)

    :ok = Command.register(state.id, guilds)

    state
  end

  def handle(%{"op" => 0, "t" => type}, state) do
    Logger.info("Received dispatch event: #{inspect(type)}.")

    state
  end

  def handle(%{"op" => 1}, state) do
    Logger.warning("Received heartbeat event.")

    state
  end

  def handle(%{"op" => 7}, state) do
    Logger.warning("Received reconnect event.")

    state
  end

  def handle(%{"op" => 9}, state) do
    Logger.warning("Received invalid session event.")

    state
  end

  def handle(%{"op" => 10, "d" => data}, state) do
    Logger.info("Received hello event.")

    state = put_in(state.interval, data["heartbeat_interval"])

    identify(state.token)

    Process.send_after(Listener, :heartbeat, state.interval)

    state
  end

  def handle(%{"op" => 11}, state) do
    Logger.info("Received heartbeat acknowledgement event.")

    Process.send_after(Listener, :heartbeat, state.interval)

    state
  end

  def handle(event, state) do
    Logger.warning("Received unhandled event: #{inspect(event)}.")

    state
  end

  def heartbeat() do
    encoded = JSON.encode!(%{op: 1, d: 0})

    GenServer.cast(Listener, {:send, {:text, encoded}})

    Logger.info("Sent heartbeat event.")
  end

  def identify(token) do
    encoded =
      JSON.encode!(%{
        op: 2,
        d: %{
          token: token,
          intents: 33_409,
          properties: %{os: "linux", browser: "doorknob", device: "doorknob"}
        }
      })

    GenServer.cast(Listener, {:send, {:text, encoded}})

    Logger.info("Sent identify event.")
  end
end
