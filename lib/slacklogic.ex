defmodule SlackLogic do

  @moduledoc """
  This module provides functionalityy to the Slack API. It is the first module
  that touches incoming messages from Slack.
  """

  use Slack

  @doc """
  This function is called whenever a connection to Slack is made.
  """
  def handle_connect(slack, state) do
    IO.puts "Connected as #{slack.me.name}"
    SlackManager.notify(:connected)
    {:ok, state}
  end

  @doc """
  This function is called whenever a message arrives from Slack.
  These messages are annotated with a type in the map, which are "regular"
  messages sent by users.

  Note that regular messages are pre-processsed to remove aliases of usernames
  which are in the form of some-sort of hashes.
  """
  def handle_event(message = %{type: "message"}, slack, state) do
    {:ok, m} = SlackManager.dealias_message(SlackManager, message.text)
    message = %{message | text: m}

    # If this message has our name in it, we send a second notification.
    if String.contains?(message.text, slack.me.name) do
      SlackManager.notify(%{message | type: "mention"})
    end

    # Notify of a regular message.
    SlackManager.notify(message)
    {:ok, state}
  end

  @doc """
  A catch-all function for events which we forward to all subscribers.
  """
  def handle_event(event, _, state) do
    SlackManager.notify(event)
    {:ok, state}
  end

  @doc """
  The close function is called whenever Slack disconnects.
  """
  def handle_close(reason, slack, state) do
    SlackManager.notify(:disconnected)
    {:ok, state}
  end


  @doc """
  Info's come from the outside. IT allows us to send messages to the Slack
  process.
  """
  def handle_info({:send, text, channel}, slack, state) do
    send_message(text, channel, slack)
    {:ok, state}
  end

  def handle_info(m, s, state) do
    {:ok, state}
  end
end
