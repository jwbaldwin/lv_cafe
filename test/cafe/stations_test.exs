defmodule Cafe.StationsTest do
  use Cafe.DataCase

  alias Cafe.Stations
  alias Cafe.Stations.{Playback, Station, Video}

  setup do
    Code.eval_file("priv/repo/seeds.exs")
    :ok
  end

  test "loads stations in category and name order" do
    names = Enum.map(Stations.list_stations(), &{&1.category, &1.name})
    assert names == Enum.sort(names)
    assert length(names) == 10
    assert Stations.get_station!(:spring).category == "seasons"
    assert Stations.get_station("missing") == nil
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

  test "static theme helpers keep reserved keyboard shortcuts unique" do
    assert Stations.get_seasons() == [:spring, :summer, :autumn, :winter]

    assert Stations.get_vibes() == [
             :blade_runner,
             :christmas,
             :cozy,
             :locked_in,
             :morning_coffee,
             :rainy_day
           ]

    shortcuts = Stations.get_stations(Stations.all_stations())
    assert map_size(shortcuts) == 10
    assert shortcuts.locked_in == %{char: "e", name: "lock[e]d_in"}
    assert shortcuts.morning_coffee == %{char: "r", name: "mo[r]ning_coffee"}
    assert shortcuts |> Map.values() |> Enum.map(& &1.char) |> Enum.uniq() |> length() == 10
  end

  test "edits preserve optimistic locking and broadcast the saved snapshot" do
    Phoenix.PubSub.subscribe(Cafe.PubSub, "stations")
    original = Stations.get_station!(:cozy)
    id = hd(original.videos).video_id

    assert {:ok, saved} = Stations.update_video(original, id, %{"title" => "Coffee and hoodie"})
    assert saved.lock_version == original.lock_version + 1
    assert hd(Stations.get_station!(:cozy).videos).title == "Coffee and hoodie"
    assert_receive {:station_updated, ^saved}
    assert {:error, :stale} = Stations.remove_video(original, id)
  end

  test "adds, moves, removes, and rejects invalid or duplicate videos" do
    station = Stations.get_station!(:cozy)
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
    station = Stations.get_station!(:cozy)
    id = hd(station.videos).video_id
    assert {:ok, _} = Stations.update_video(station, id, %{"title" => "custom title"})

    Code.eval_file("priv/repo/seeds.exs")
    assert hd(Stations.get_station!(:cozy).videos).title == "custom title"
  end
end
