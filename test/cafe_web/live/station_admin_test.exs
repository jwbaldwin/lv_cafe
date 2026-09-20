defmodule CafeWeb.StationAdminTest do
  use CafeWeb.ConnCase
  import Phoenix.LiveViewTest
  import Cafe.StationsFixtures
  alias Cafe.{Repo, Stations}
  alias CafeWeb.AdminAuth

  setup do
    Code.eval_file("priv/repo/seeds.exs")
    previous = Application.get_env(:cafe, :admin_password)
    Application.put_env(:cafe, :admin_password, "station-admin-test")
    on_exit(fn -> Application.put_env(:cafe, :admin_password, previous) end)
    :ok
  end

  defp admin(path) do
    live(init_test_session(build_conn(), admin_token: AdminAuth.token()), path)
  end

  test "create, select, rename, and reconnect using database settings", %{conn: conn} do
    {:ok, player, _} = live(conn, "/")
    {:ok, admin, _} = admin("/admin?new=true")
    attrs = station_attrs() |> Map.delete("videos")

    admin
    |> form("#new-station", station: attrs, video_url: "https://youtu.be/abcdefghijk")
    |> render_submit()

    station = station_named("Night train")
    assert_patch(admin, "/admin?station=#{station.id}")
    assert render(admin) =~ "Station created"
    assert has_element?(player, "#station-#{station.id}[data-station-key=n]", "Night train")

    assert has_element?(
             player,
             "#station-#{station.id} img[src='https://example.com/train.webp']"
           )

    player |> element("#station-#{station.id}") |> render_click()
    assert_push_event(player, "changeVideo", %{video_id: "abcdefghijk"})
    id = to_string(station.id)
    assert_push_event(player, "store_station", %{station_id: ^id})

    admin
    |> form("#station-settings",
      station: %{
        name: "Midnight express",
        shortcut: "x",
        category: "Rail",
        position: 0,
        effect: "winter",
        image_url: "https://example.com/new.webp"
      }
    )
    |> render_submit()

    assert has_element?(player, "#station-#{station.id}[data-station-key=x]", "Midnight express")
    assert has_element?(player, "#station-#{station.id} img[src='https://example.com/new.webp']")
    assert has_element?(player, ".snow-effect")
    assert :sys.get_state(player.pid).socket.assigns.playback.video_id == "abcdefghijk"
    refute_push_event(player, "changeVideo", %{}, 20)

    {:ok, reconnected, _} = live(put_connect_params(build_conn(), %{"station_id" => id}), "/")
    assert :sys.get_state(reconnected.pid).socket.assigns.station.name == "Midnight express"

    render_hook(reconnected, "player_ready", %{video_id: "abcdefghijk", title: "Still playing"})
    assert render(reconnected) =~ "Still playing"

    admin |> form("#station-settings", station: %{image_url: ""}) |> render_submit()
    refute has_element?(player, "#station-#{station.id} img")
    assert has_element?(player, "#station-#{station.id}", "♫")
    reconnected |> element("#feedback-toggle") |> render_click()

    reconnected
    |> form("#feedback-form", feedback: %{message: "Love this station"})
    |> render_submit()

    assert [%{station_name: "Midnight express", video_id: "abcdefghijk"}] =
             Cafe.Curation.list_feedback()
  end

  test "creation shows errors and preserves entered settings" do
    {:ok, admin, _} = admin("/admin?new=true")
    attrs = station_attrs(%{"shortcut" => "s"}) |> Map.delete("videos")
    admin |> form("#new-station", station: attrs, video_url: "abcdefghijk") |> render_submit()
    assert render(admin) =~ "has already been taken"
    assert has_element?(admin, "input[name='station[name]'][value='Night train']")
    assert has_element?(admin, "input[name=video_url][value=abcdefghijk]")
    assert length(Stations.list_stations()) == 10

    admin |> form("#new-station", station: %{shortcut: "n"}, video_url: "bad") |> render_submit()
    assert render(admin) =~ "Enter a valid YouTube"
    assert length(Stations.list_stations()) == 10
  end

  test "stale settings load the latest version after a rename" do
    station = station_named("cozy")
    {:ok, first, _} = admin("/admin?station=#{station.id}")
    {:ok, second, _} = admin("/admin?station=#{station.id}")
    first |> form("#station-settings", station: %{name: "Coffee room"}) |> render_submit()
    second |> form("#station-settings", station: %{name: "Stale name"}) |> render_submit()
    assert render(second) =~ "This station changed in another browser"
    assert has_element?(second, "input[name='station[name]'][value='Coffee room']")
    assert Stations.get_station!(station.id).name == "Coffee room"
  end

  test "the first station can be created from an empty catalog", %{conn: conn} do
    Repo.delete_all(Stations.Station)
    {:ok, player, html} = live(conn, "/")
    assert html =~ "No stations are available"
    {:ok, admin, _} = admin("/admin")
    admin |> element("a", "+ Add station") |> render_click()
    assert_patch(admin, "/admin?new=true")

    admin
    |> form("#new-station",
      station: Map.delete(station_attrs(), "videos"),
      video_url: "abcdefghijk"
    )
    |> render_submit()

    assert has_element?(player, "#youtube-player-container[data-video-id=abcdefghijk]")
  end
end
