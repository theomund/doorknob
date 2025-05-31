defmodule Doorknob.Discord.Gateway.Event do
  @moduledoc """
  Convenience functions for creating Discord Gateway API events.
  """

  require Logger

  def heartbeat(state) do
    encoded = JSON.encode!(%{op: 1, d: 0})

    :gun.ws_send(state.pid, state.ref, {:text, encoded})

    Logger.info("Sent heartbeat event.")
  end

  def identify(state) do
    encoded =
      JSON.encode!(%{
        op: 2,
        d: %{
          token: state.token,
          intents: 513,
          properties: %{os: "linux", browser: "doorknob", device: "doorknob"}
        }
      })

    :gun.ws_send(state.pid, state.ref, {:text, encoded})

    Logger.info("Sent identify event.")
  end
end
