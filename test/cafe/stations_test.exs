defmodule Cafe.StationsTest do
  use Cafe.DataCase

  alias Cafe.Stations

  test "get_seasons/0 returns a list of seasons" do
    assert Stations.get_seasons() == [:spring, :summer, :autumn, :winter]
  end

  test "get_vibes/0 returns a list of vibes" do
    assert Stations.get_vibes() == [
             :blade_runner,
             :christmas,
             :cozy,
             :locked_in,
             :morning_coffee,
             :rainy_day
           ]
  end

  test "get_station/3 returns a station by theme and position" do
    assert {:ok,
            %Stations.Station{
              name: "spring",
              position: 0,
              video_id: "ZMjdwYVmnog"
            }} == Stations.fetch_station(:seasons, :spring, 0)

    assert {:ok,
            %Stations.Station{
              name: "blade_runner",
              position: 0,
              video_id: "UjlMEqTu2KI"
            }} == Stations.fetch_station(:vibes, :blade_runner, 0)
  end

  test "get_get_unique_key_map_for_themes/1 returns a map of unique keys for each theme" do
    assert %{
             :autumn => %{char: "a", name: "[a]utumn"}
           } == Stations.get_stations([:autumn])
  end

  test "get_stations/1 gives every station a unique shortcut" do
    stations = Stations.get_stations(Stations.get_seasons() ++ Stations.get_vibes())

    assert map_size(stations) == 10
    assert stations.locked_in == %{char: "e", name: "lock[e]d_in"}
    refute Enum.any?(Map.values(stations), &(&1.char in ~w(h j k l p m t)))
    assert stations.autumn == %{char: "a", name: "[a]utumn"}
    assert stations.morning_coffee == %{char: "r", name: "mo[r]ning_coffee"}
    assert stations |> Map.values() |> Enum.map(& &1.char) |> Enum.uniq() |> length() == 10
  end

  test "recordings join in progress without seeking into the ending or changing live streams" do
    video = %{"start_seconds" => 30, "duration_seconds" => 100, "tune_in" => true}
    assert Stations.playback_start(video, 0) == 30
    assert Stations.playback_start(video, 59) == 89
    assert Stations.playback_start(video, 60) == 30
    assert Stations.playback_start(Map.put(video, "live", true), 59) == 0
    assert Stations.playback_start(%{}, 59) == 0
    assert Stations.playback_start(%{"start_seconds" => 12}, 59) == 12
  end

  test "expanded playlists wrap arbitrary offsets in both directions" do
    assert Stations.station_count(:vibes, :christmas) == 6

    for index <- -13..13 do
      assert {:ok, station} = Stations.fetch_station(:vibes, :christmas, index)
      assert station.position == Integer.mod(index, 6)
    end
  end
end
