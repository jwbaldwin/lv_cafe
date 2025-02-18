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
    assert Stations.get_station(:seasons, :spring, 0) == %Stations.Station{
             position: 0,
             video_id: "If_UO5D9SdU"
           }

    assert Stations.get_station(:vibes, :blade_runner, 0) == %Stations.Station{
             position: 0,
             video_id: "UDxVZ-_0KUw"
           }
  end
end
