defmodule Cafe.Stations do
  @moduledoc """
  The Stations context.
  """

  import Ecto.Query, warn: false

  alias Cafe.Stations.Station

  # Mute, toggle themes, and pause/play are reserved for the UI
  @global_keys ["m", "t", " "]

  @stations %{
    seasons: %{
      spring: ["If_UO5D9SdU", "hN5bD_dV20g"],
      summer: ["U537141YqTI", "8-BsxrE1bY8"],
      autumn: ["zFXNZNKxDvs", "99PHofIMRaU", "Vg13S-zzol0", "pa6CyLN3wPY"],
      winter: ["C5Jrme_XWyA", "HNCgEbZN65s"]
    },
    vibes: %{
      blade_runner: ["UDxVZ-_0KUw", "-sZqtdT-GVw", "S7i3ugniyjg", "A4kU-LiaXiE"],
      christmas: ["UGzTkPauX8U", "grQl_OaN2BQ"],
      cozy: ["jfKfPfyJRdk", "ySEqsRMPjz8"],
      locked_in: ["OvM7WAzfBHs", "Yd7vDterctQ", "6rvv8bU3pKA"],
      rainy_day: ["ifptFpMbcn4", "DEWzT1geuPU"],
      morning_coffee: ["GRSTnYTpDw8", "Rs0EOzsJPU0"]
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
  def fetch_station(theme, sub_theme, station_number) when is_integer(station_number) do
    case get_in(@stations, [theme, sub_theme]) do
      nil ->
        {:error, :station_not_found}

      [] ->
        {:error, :station_empty}

      stations ->
        station_number =
          case station_number do
            station_number when station_number > length(stations) - 1 -> 0
            station_number when station_number < 0 -> length(stations) - 1
            station_number -> station_number
          end

        if video_id = Enum.at(stations, station_number) do
          {:ok, %Station{video_id: video_id, position: station_number}}
        else
          {:error, :video_not_found}
        end
    end
  end

  @doc """
  Takes all the theme names and returns a map of unique keys for each theme
  with the found key bracketed in the name.

  e.g. "[s]pring" => "s"
  """
  def get_stations(theme_names) do
    theme_names
    |> Enum.with_index()
    |> Enum.reduce(%{keys: MapSet.new(@global_keys), mapping: %{}}, fn {name, index},
                                                                       %{
                                                                         keys: set,
                                                                         mapping: mapping
                                                                       } ->
      string_name = Atom.to_string(name)

      char = get_unique_character(set, string_name, 0, index)
      styled_name = get_styled_name(string_name, char)

      %{
        keys: MapSet.put(set, char),
        mapping: Map.put(mapping, name, %{char: char, name: styled_name})
      }
    end)
    |> then(& &1.mapping)
  end

  defp get_styled_name(name, char) when is_integer(char) do
    "[#{char}] " <> name
  end

  defp get_styled_name(name, char) do
    String.replace(name, char, "[#{char}]", global: false)
  end

  defp get_unique_character(set, name, position, index_fallback)
       when position < byte_size(name) do
    test_char = String.at(name, position)

    if MapSet.member?(set, test_char) do
      get_unique_character(set, name, position + 1, index_fallback)
    else
      test_char
    end
  end

  defp get_unique_character(_set, _name, _position, index_fallback), do: index_fallback
end
