defmodule Cafe.Stations do
  @moduledoc """
  The Stations context.
  """

  import Ecto.Query, warn: false

  alias Cafe.Stations.Station

  # Mute, toggle themes, pause/play, navigation, and volume controls are reserved for the UI
  @global_keys ["p", "m", "t", " ", "ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"]
  @seasons [:spring, :summer, :autumn, :winter]

  @stations %{
    seasons: %{
      spring: ["ZMjdwYVmnog", "hODhrZlpcgo", "aP139Pah2c8"],
      summer: ["NWw1ZuDIjlw", "gUbNlN_SqpE", "-VjOjBLpMws"],
      autumn: ["pa6CyLN3wPY", "X59TpY0qtHE", "hrd0MSGc2Lk"],
      winter: ["XVSL1DgGGiw", "tONVgIvdk0A", "S-4hwfyK-XQ"]
    },
    vibes: %{
      blade_runner: ["4FhsjQ2xess", "XB0e7pI3Q8I", "svS19DWJ5t4"],
      christmas: ["qwdzIECTqn8", "wQwqjzdwIyw", "Rnx08JFs6nQ"],
      cozy: ["tIMtzkZ93gg", "s6XIt0vUq6A", "AUT4ZdXi37s"],
      locked_in: ["00fOyOzuSfM", "EN0A5derVo0", "9M4jZuqdw04"],
      rainy_day: ["DEWzT1geuPU", "3u0wlqe8lVk", "lCrqRhCt-oM"],
      morning_coffee: ["3E0iUbAnCsM", "337OKHV3BRI", "1fueZCTYkpA"]
    }
  }

  def all_stations() do
    get_seasons() ++ get_vibes()
  end

  def get_seasons() do
    @seasons
  end

  def get_vibes() do
    @stations[:vibes]
    |> Map.keys()
    |> Enum.sort()
  end

  def station_count(theme, sub_theme) do
    @stations
    |> get_in([theme, sub_theme])
    |> case do
      stations when is_list(stations) -> length(stations)
      nil -> 0
    end
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
          {:ok,
           %Station{name: Atom.to_string(sub_theme), video_id: video_id, position: station_number}}
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
