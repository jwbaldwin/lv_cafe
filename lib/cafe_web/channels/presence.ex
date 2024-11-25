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

  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    # fetch existing presence information for the joined users and broadcast the
    # event to all subscribers
    for {user_id, presence} <- joins do
      user_data = %{user: presence.user, metas: Map.fetch!(presences, user_id)}
      msg = {Cafe.PresenceClient, {:join, user_data}}
      Phoenix.PubSub.local_broadcast(Cafe.PubSub, topic, msg)
    end

    # fetch existing presence information for the left users and broadcast the
    # event to all subscribers
    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{user: presence.user, metas: metas}
      msg = {Cafe.PresenceClient, {:leave, user_data}}
      Phoenix.PubSub.local_broadcast(Cafe.PubSub, topic, msg)
    end

    {:ok, state}
  end
end
