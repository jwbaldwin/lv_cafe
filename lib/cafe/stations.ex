defmodule Cafe.Stations do
  @moduledoc """
  The Stations context.
  """

  import Ecto.Query, warn: false

  alias Cafe.Stations.Station

  @stations ["UGzTkPauX8U", "grQl_OaN2BQ"]

  @doc """
  Get the specific station
  """
  def get_station(n) when is_integer(n) do
    IO.inspect(n)

    position =
      case n do
        n when n > length(@stations) - 1 -> 0
        n when n < 0 -> length(@stations) - 1
        n -> n
      end

    video_id = Enum.at(@stations, position)
    %Station{video_id: video_id, position: position}
  end
end
