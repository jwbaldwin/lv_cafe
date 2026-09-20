defmodule Cafe.StationsTest do
  import Cafe.StationsFixtures
  use Cafe.DataCase

  alias Cafe.Stations
  alias Cafe.Stations.{Playback, Station, Video}

  setup do
    Code.eval_file("priv/repo/seeds.exs")
    :ok
  end

  test "loads stations in display order" do
    names = Enum.map(Stations.list_stations(), &{&1.position, &1.id})
    assert names == Enum.sort(names)
    assert length(names) == 10
    assert station_named(:spring).category == "seasons"
    assert Stations.get_station!(station_named("spring").id).name == "spring"
  end

  test "select_video is pure, wraps arbitrary positions, and computes playback" do
    station = %Station{
      name: "test",
      category: "vibes",
      videos: [
        %Video{video_id: "aaaaaaaaaaa"},
        %Video{video_id: "bbbbbbbbbbb", start_seconds: 30, duration_seconds: 100, tune_in: true}
      ]
    }

    assert {:ok, %Playback{video_id: "bbbbbbbbbbb", position: 1, start_seconds: start}} =
             Stations.select_video(station, -1)

    assert start in 30..89

    assert {:ok, %Playback{video_id: "aaaaaaaaaaa", position: 0, start_seconds: 0}} =
             Stations.select_video(station, 2)

    assert Stations.select_video(%Station{videos: []}, 0) == {:error, :station_empty}
  end

  test "recordings join in progress without seeking into the ending or changing live streams" do
    video = %Video{start_seconds: 30, duration_seconds: 100, tune_in: true}
    assert Stations.playback_start(video, 0) == 30
    assert Stations.playback_start(video, 59) == 89
    assert Stations.playback_start(video, 60) == 30
    assert Stations.playback_start(%{video | live: true}, 59) == 0
    assert Stations.playback_start(%Video{}, 59) == 0
    assert Stations.playback_start(%Video{start_seconds: 12}, 59) == 12
  end

  test "creates stations, rejects conflicting shortcuts, and broadcasts settings edits" do
    Phoenix.PubSub.subscribe(Cafe.PubSub, "stations")
    assert {:ok, station} = Stations.create_station(station_attrs())
    assert_receive {:station_updated, ^station}
    assert {:error, changeset} = Stations.create_station(station_attrs(%{"name" => "Another"}))
    assert "has already been taken" in errors_on(changeset).shortcut

    for key <- ~w(p f m t h j k l ? ab) do
      assert {:error, changeset} = Stations.create_station(station_attrs(%{"shortcut" => key}))
      assert errors_on(changeset).shortcut
    end

    assert {:ok, edited} =
             Stations.update_station(station, %{
               "name" => "Renamed",
               "shortcut" => "X",
               "effect" => "winter"
             })

    assert edited.id == station.id
    assert edited.shortcut == "x"
    assert_receive {:station_updated, ^edited}
    assert {:error, :stale} = Stations.update_station(station, %{"name" => "Stale"})
  end

  test "validates settings and requires a playable first video" do
    for attrs <- [
          %{"videos" => []},
          %{"image_url" => "javascript:alert(1)"},
          %{"image_url" => "//example.com/x"},
          %{"position" => -1},
          %{"effect" => "unknown"},
          %{"name" => " "}
        ] do
      assert {:error, _} = Stations.create_station(station_attrs(attrs))
    end

    assert {:ok, _} = Stations.create_station(station_attrs(%{"image_url" => ""}))
  end

  test "seed reruns preserve renamed stations and all their settings" do
    original = station_named("cozy")

    assert {:ok, updated} =
             Stations.update_station(original, %{
               "name" => "My cafe",
               "category" => "Work",
               "shortcut" => "z",
               "position" => 99,
               "image_url" => "https://example.com/new.webp",
               "effect" => "spring"
             })

    Code.eval_file("priv/repo/seeds.exs")
    assert Stations.get_station!(original.id) == updated
    assert length(Stations.list_stations()) == 10
  end

  test "edits preserve optimistic locking and broadcast the saved snapshot" do
    Phoenix.PubSub.subscribe(Cafe.PubSub, "stations")
    original = station_named(:cozy)
    id = hd(original.videos).video_id

    assert {:ok, saved} = Stations.update_video(original, id, %{"title" => "Coffee and hoodie"})
    assert saved.lock_version == original.lock_version + 1
    assert hd(station_named(:cozy).videos).title == "Coffee and hoodie"
    assert_receive {:station_updated, ^saved}
    assert {:error, :stale} = Stations.remove_video(original, id)
  end

  test "adds, moves, removes, and rejects invalid or duplicate videos" do
    station = station_named(:cozy)
    assert {:ok, station} = Stations.add_video(station, "https://youtu.be/vIlzvUsB6H0")
    assert List.last(station.videos).video_id == "vIlzvUsB6H0"
    assert {:error, _} = Stations.add_video(station, "vIlzvUsB6H0")
    assert {:ok, station} = Stations.move_video(station, "vIlzvUsB6H0", -1)
    assert Enum.at(station.videos, 2).video_id == "vIlzvUsB6H0"

    station =
      Enum.reduce(Enum.drop(station.videos, 1), station, fn video, station ->
        assert {:ok, updated} = Stations.remove_video(station, video.video_id)
        updated
      end)

    assert {:error, _} = Stations.remove_video(station, hd(station.videos).video_id)
    assert {:error, :invalid_url} = Stations.add_video(station, "https://evil.example/video")
  end

  test "rerunning seeds preserves station edits" do
    station = station_named(:cozy)
    id = hd(station.videos).video_id
    assert {:ok, _} = Stations.update_video(station, id, %{"title" => "custom title"})

    Code.eval_file("priv/repo/seeds.exs")
    assert hd(station_named(:cozy).videos).title == "custom title"
  end
end
