defmodule CafeWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :cafe,
    pubsub_server: Cafe.PubSub

  def init(_opts) do
    # user-land state
    {:ok, %{}}
  end

  def fetch(_topic, presences) do
    for {key, %{metas: [meta | metas]}} <- presences, into: %{} do
      # user could be populated here from the database here we populate
      {key, %{metas: [meta | metas]}}
    end
  end

  def handle_metas(topic, %{joins: joins, leaves: leaves}, _presences, state) do
    # For joins, we just need to broadcast the session_id
    for {session_id, _presence} <- joins do
      msg = {__MODULE__, {:join, session_id}}
      Phoenix.PubSub.local_broadcast(Cafe.PubSub, "proxy:#{topic}", msg)
    end

    # For leaves, same simplification
    for {session_id, _presence} <- leaves do
      msg = {__MODULE__, {:leave, session_id}}
      Phoenix.PubSub.local_broadcast(Cafe.PubSub, "proxy:#{topic}", msg)
    end

    {:ok, state}
  end

  def list_online_users(station),
    do: list(station) |> Enum.count()

  def track_user(station, name, params \\ %{}) do
    track(self(), station, name, params)
  end

  def subscribe(station), do: Phoenix.PubSub.subscribe(Cafe.PubSub, "proxy:#{station}")
end
