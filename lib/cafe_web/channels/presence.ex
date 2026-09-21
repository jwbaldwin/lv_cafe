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
    {:ok, %{}}
  end

  def handle_metas(_topic, _diff, _presences, state) do
    Phoenix.PubSub.broadcast(Cafe.PubSub, "listeners", :listeners_changed)
    {:ok, state}
  end

  def list_all_listener_counts(station_ids) do
    Map.new(station_ids, &{&1, list_online_users(&1)})
  end

  def list_online_users(station),
    do: list(station) |> Enum.count()

  def track_user(station, name, params \\ %{}) do
    track(self(), station, name, params)
  end
end
