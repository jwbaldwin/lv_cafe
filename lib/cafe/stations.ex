defmodule Cafe.Stations do
  @moduledoc """
  The Stations context.
  """

  import Ecto.Query, warn: false

  alias Cafe.Stations.Station

  @stations %{
    seasons: %{
      summer: [],
      spring: [],
      autumn: [],
      winter: ["UGzTkPauX8U", "grQl_OaN2BQ"]
    },
    vibes: %{
      rainy_day: []
    }
  }

  @doc """
  Get the specific station by theme and position
  """
  def get_station(theme, sub_theme, station_number) when is_integer(station_number) do
    IO.inspect(theme)
    stations = get_in(@stations, [theme, sub_theme])

    station_number =
      case station_number do
        station_number when station_number > length(stations) - 1 -> 0
        station_number when station_number < 0 -> length(stations) - 1
        station_number -> station_number
      end

    IO.inspect(stations)
    IO.inspect(station_number)
    video_id = Enum.at(stations, station_number)
    %Station{video_id: video_id, position: station_number}
  end
end
