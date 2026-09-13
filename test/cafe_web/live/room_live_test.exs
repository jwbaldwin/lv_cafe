defmodule CafeWeb.RoomLiveTest do
  use CafeWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Cafe.Stations

  setup %{conn: conn} do
    Code.eval_file("priv/repo/seeds.exs")

    conn =
      put_connect_params(conn, %{
        "preferences" => %{"theme" => "seasons", "sub_theme" => "winter"}
      })

    {:ok, view, _html} = live(conn, "/")
    {:ok, view: view}
  end

  test "unavailable videos are skipped once, then stop with a useful message", %{view: view} do
    count = length(Stations.get_station!("winter").videos)

    for position <- 0..(count - 1) do
      {:ok, station} = Stations.select_video(Stations.get_station!("winter"), position)
      render_hook(view, "player_error", %{video_id: station.video_id})

      if position < count - 1 do
        {:ok, next} = Stations.select_video(Stations.get_station!("winter"), position + 1)
        next_id = next.video_id
        assert_push_event(view, "changeVideo", %{video_id: ^next_id, volume: 50})
      end
    end

    assert render(view) =~ "no videos available"
    assert_push_event(view, "playerUnavailable", %{})
  end

  test "late events from the old video cannot overwrite the new title or skip it", %{view: view} do
    {:ok, old} = Stations.select_video(Stations.get_station!("winter"), 0)
    view |> element("button[phx-click=next_video]") |> render_click()
    {:ok, current} = Stations.select_video(Stations.get_station!("winter"), 1)
    current_id = current.video_id
    assert_push_event(view, "changeVideo", %{video_id: ^current_id, volume: 50})
    render_hook(view, "player_ready", %{video_id: current.video_id, title: "Current video"})
    render_hook(view, "player_error", %{video_id: old.video_id})
    render_hook(view, "player_ready", %{video_id: old.video_id, title: "Old video"})
    assert render(view) =~ "Current video"
    refute render(view) =~ "Old video"
  end

  test "switching themes moves presence and updates counts", %{view: view} do
    view |> element("button[phx-value-sub_theme=cozy]") |> render_click()
    # Wait for the tracker to publish its asynchronous update.
    eventually(fn ->
      assert CafeWeb.Presence.list_online_users("winter") == 0
      assert CafeWeb.Presence.list_online_users("cozy") == 1
      assert view |> element("button[phx-value-sub_theme=cozy]") |> render() =~ "1"
    end)
  end

  test "video end advances with the current volume", %{view: view} do
    {:ok, station} = Stations.select_video(Stations.get_station!("winter"), 0)
    render_hook(view, "player_state", %{playing: true, muted: false, volume: 30})
    render_hook(view, "player_ended", %{video_id: station.video_id})
    {:ok, next} = Stations.select_video(Stations.get_station!("winter"), 1)
    next_id = next.video_id
    assert_push_event(view, "changeVideo", %{video_id: ^next_id, volume: 30})
  end

  test "ordinary component updates do not tick a running timer" do
    socket = %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}, timer_state: :running, time_left: 1500}
    }

    assert {:ok, updated} = CafeWeb.PomodoroTimer.update(%{id: "pomodoro-timer"}, socket)
    assert updated.assigns.time_left == 1500
    refute_receive {:phoenix, :send_update, _}, 20
  end

  test "navigation, station changes, video end and errors perform no database queries", %{
    view: view
  } do
    owner = self()
    handler = {__MODULE__, make_ref()}
    :ok = :telemetry.attach(handler, [:cafe, :repo, :query], &__MODULE__.record_query/4, owner)
    on_exit(fn -> :telemetry.detach(handler) end)

    # Prove the observer sees real queries before measuring the player.
    Stations.get_station!("winter")
    assert_receive {:database_query, _}

    for _ <- 1..10 do
      view |> element("button[phx-click=next_video]") |> render_click()
      view |> element("button[phx-click=prev_video]") |> render_click()
    end

    send(view.pid, {:change_theme, "vibes", "cozy"})
    render(view)
    state = :sys.get_state(view.pid).socket.assigns
    render_hook(view, "player_ended", %{video_id: state.playback.video_id})
    state = :sys.get_state(view.pid).socket.assigns
    render_hook(view, "player_error", %{video_id: state.playback.video_id})
    render(view)
    refute_receive {:database_query, _}, 50
  end

  test "an edit to another station refreshes the catalog before switching to it", %{view: view} do
    station = Stations.get_station!("cozy")
    assert {:ok, updated} = Stations.move_video(station, hd(station.videos).video_id, 1)
    render(view)

    assert :sys.get_state(view.pid).socket.assigns.catalog["cozy"].lock_version ==
             updated.lock_version

    view |> element("button[phx-value-sub_theme=cozy]") |> render_click()
    first_id = hd(updated.videos).video_id
    assert_push_event(view, "changeVideo", %{video_id: ^first_id})
  end

  test "reordering preserves current playback and older refresh messages cannot undo it", %{
    view: view
  } do
    original = Stations.get_station!("winter")
    first = hd(original.videos).video_id
    render_hook(view, "player_ready", %{video_id: first, title: "Keep playing"})
    assert {:ok, updated} = Stations.move_video(original, first, 1)
    render(view)
    state = :sys.get_state(view.pid).socket.assigns
    assert state.playback.video_id == first
    assert state.playback.position == 1
    assert state.title == "Keep playing"
    refute_push_event(view, "changeVideo", %{}, 20)

    send(view.pid, {:station_updated, original})
    render(view)
    state = :sys.get_state(view.pid).socket.assigns
    assert state.station.lock_version == updated.lock_version
    assert state.playback.position == 1
  end

  test "missing or untrusted saved preferences use a valid default" do
    {:ok, view, _} =
      live(
        put_connect_params(build_conn(), %{
          "preferences" => %{"theme" => "unknown", "sub_theme" => "unknown"}
        }),
        "/"
      )

    assert :sys.get_state(view.pid).socket.assigns.station.name == "cozy"
    send(view.pid, {:change_theme, "unknown", "unknown"})
    assert render(view) =~ "youtube-player-container"
    assert :sys.get_state(view.pid).socket.assigns.station.name == "cozy"
  end

  def record_query(_event, _measurements, metadata, owner),
    do: send(owner, {:database_query, metadata.query})

  defp eventually(assertion, attempts \\ 30) do
    assertion.()
  rescue
    error in ExUnit.AssertionError ->
      if attempts == 0, do: reraise(error, __STACKTRACE__)
      Process.sleep(10)
      eventually(assertion, attempts - 1)
  end
end
