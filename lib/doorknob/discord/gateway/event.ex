defmodule Doorknob.Discord.Gateway.Event do
  @moduledoc """
  Convenience functions for creating Discord Gateway API events.
  """

  alias Doorknob.Discord.Gateway.Listener

  require Logger

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
