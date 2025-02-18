defmodule Cafe.Stations do
  @moduledoc """
  The Stations context.
  """

  import Ecto.Query, warn: false

  alias Cafe.Stations.Station

  @stations %{
    seasons: %{
      spring: ["If_UO5D9SdU", "hN5bD_dV20g"],
      summer: ["U537141YqTI", "8-BsxrE1bY8"],
      autumn: ["zFXNZNKxDvs", "99PHofIMRaU", "Vg13S-zzol0", "pa6CyLN3wPY"],
      winter: ["UGzTkPauX8U", "grQl_OaN2BQ"]
    },
    vibes: %{
      blade_runner: ["UDxVZ-_0KUw"],
      christmas: [],
      cozy: [],
      locked_in: ["OvM7WAzfBHs", "Yd7vDterctQ", "6rvv8bU3pKA"],
      rainy_day: []
    }
  }

  def get_seasons() do
    @stations[:seasons]
    |> Map.keys()
  end

  def get_vibes() do
    @stations[:vibes]
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Get the specific station by theme and position
  """
  def get_station(theme, sub_theme, station_number) when is_integer(station_number) do
    stations = get_in(@stations, [theme, sub_theme])

    station_number =
      case station_number do
        station_number when station_number > length(stations) - 1 -> 0
        station_number when station_number < 0 -> length(stations) - 1
        station_number -> station_number
      end

    video_id = Enum.at(stations, station_number)
    %Station{video_id: video_id, position: station_number}
  end

  def get_stations() do
    @stations
  end
end
