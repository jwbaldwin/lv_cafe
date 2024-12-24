defmodule Cafe.StationsTest do
  use Cafe.DataCase

  alias Cafe.Stations

  describe "stations" do
    alias Cafe.Stations.Station

    import Cafe.StationsFixtures

    @invalid_attrs %{name: nil, video_id: nil}

    test "list_stations/0 returns all stations" do
      station = station_fixture()
      assert Stations.list_stations() == [station]
    end

    test "get_station!/1 returns the station with given id" do
      station = station_fixture()
      assert Stations.get_station!(station.id) == station
    end

    test "create_station/1 with valid data creates a station" do
      valid_attrs = %{name: "some name", video_id: "some video_id"}

      assert {:ok, %Station{} = station} = Stations.create_station(valid_attrs)
      assert station.name == "some name"
      assert station.video_id == "some video_id"
    end

    test "create_station/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Stations.create_station(@invalid_attrs)
    end

    test "update_station/2 with valid data updates the station" do
      station = station_fixture()
      update_attrs = %{name: "some updated name", video_id: "some updated video_id"}

      assert {:ok, %Station{} = station} = Stations.update_station(station, update_attrs)
      assert station.name == "some updated name"
      assert station.video_id == "some updated video_id"
    end

    test "update_station/2 with invalid data returns error changeset" do
      station = station_fixture()
      assert {:error, %Ecto.Changeset{}} = Stations.update_station(station, @invalid_attrs)
      assert station == Stations.get_station!(station.id)
    end

    test "delete_station/1 deletes the station" do
      station = station_fixture()
      assert {:ok, %Station{}} = Stations.delete_station(station)
      assert_raise Ecto.NoResultsError, fn -> Stations.get_station!(station.id) end
    end

    test "change_station/1 returns a station changeset" do
      station = station_fixture()
      assert %Ecto.Changeset{} = Stations.change_station(station)
    end
  end
end
