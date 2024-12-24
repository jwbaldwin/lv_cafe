defmodule Cafe.StationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Cafe.Stations` context.
  """

  @doc """
  Generate a station.
  """
  def station_fixture(attrs \\ %{}) do
    {:ok, station} =
      attrs
      |> Enum.into(%{
        name: "some name",
        video_id: "some video_id"
      })
      |> Cafe.Stations.create_station()

    station
  end
end
