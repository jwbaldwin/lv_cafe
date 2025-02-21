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
             :rainy_day
           ]
  end

  test "get_station/3 returns a station by theme and position" do
    assert {:ok,
            %Stations.Station{
              position: 0,
              video_id: "If_UO5D9SdU"
            }} == Stations.fetch_station(:seasons, :spring, 0)

    assert {:ok,
            %Stations.Station{
              position: 0,
              video_id: "UDxVZ-_0KUw"
            }} == Stations.fetch_station(:vibes, :blade_runner, 0)
  end

  test "get_get_unique_key_map_for_themes/1 returns a map of unique keys for each theme" do
    assert %{
             :autumn => %{char: "a", name: "[a]utumn"}
           } == Stations.get_stations([:autumn])
  end

  test "get_get_unique_key_map_for_themes/1 returns a map of unique keys for each theme morning" do
    assert %{
             :autumn => %{char: "a", name: "[a]utumn"}
           } == Stations.get_stations(Stations.get_seasons() ++ Stations.get_vibes())
  end
end
