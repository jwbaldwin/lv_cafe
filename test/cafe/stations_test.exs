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
end
