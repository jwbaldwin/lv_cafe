defmodule CafeWeb.RoomLiveTest do
  use CafeWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Cafe.Stations

  setup %{conn: conn} do
    conn =
      put_connect_params(conn, %{
        "preferences" => %{"theme" => "seasons", "sub_theme" => "winter"}
      })

    {:ok, view, _html} = live(conn, "/")
    {:ok, view: view}
  end

  test "unavailable videos are skipped once, then stop with a useful message", %{view: view} do
    count = Stations.station_count(:seasons, :winter)

    for position <- 0..(count - 1) do
      {:ok, station} = Stations.fetch_station(:seasons, :winter, position)
      render_hook(view, "player_error", %{video_id: station.video_id})

      if position < count - 1 do
        {:ok, next} = Stations.fetch_station(:seasons, :winter, position + 1)
        next_id = next.video_id
        assert_push_event(view, "changeVideo", %{video_id: ^next_id, volume: 50})
      end
    end

    assert render(view) =~ "no videos available"
    assert_push_event(view, "playerUnavailable", %{})
  end

  test "late events from the old video cannot overwrite the new title or skip it", %{view: view} do
    {:ok, old} = Stations.fetch_station(:seasons, :winter, 0)
    view |> element("button[phx-click=next_station]") |> render_click()
    {:ok, current} = Stations.fetch_station(:seasons, :winter, 1)
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
    {:ok, station} = Stations.fetch_station(:seasons, :winter, 0)
    render_hook(view, "player_state", %{playing: true, muted: false, volume: 30})
    render_hook(view, "player_ended", %{video_id: station.video_id})
    {:ok, next} = Stations.fetch_station(:seasons, :winter, 1)
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

  defp eventually(assertion, attempts \\ 30) do
    assertion.()
  rescue
    error in ExUnit.AssertionError ->
      if attempts == 0, do: reraise(error, __STACKTRACE__)
      Process.sleep(10)
      eventually(assertion, attempts - 1)
  end
end
