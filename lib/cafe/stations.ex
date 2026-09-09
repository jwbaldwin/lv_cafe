defmodule Cafe.Stations do
  @moduledoc """
  The Stations context.
  """

  import Ecto.Query, warn: false

  alias Cafe.Stations.Station

  # Mute, toggle themes, pause/play, navigation, and volume controls are reserved for the UI
  @global_keys [
    "p",
    "m",
    "t",
    "h",
    "j",
    "k",
    "l",
    " ",
    "ArrowLeft",
    "ArrowRight",
    "ArrowUp",
    "ArrowDown"
  ]
  @seasons [:spring, :summer, :autumn, :winter]

  @vibes [:blade_runner, :christmas, :cozy, :locked_in, :morning_coffee, :rainy_day]

  def all_stations() do
    get_seasons() ++ get_vibes()
  end

  def get_seasons() do
    @seasons
  end

  def get_vibes() do
    @vibes
  end

  def station_count(theme, sub_theme) do
    videos(theme, sub_theme)
    |> case do
      stations when is_list(stations) -> length(stations)
      nil -> 0
    end
  end

  @doc """
  Get the specific station by theme and position
  """
  def fetch_station(theme, sub_theme, station_number) when is_integer(station_number) do
    case videos(theme, sub_theme) do
      nil ->
        {:error, :station_not_found}

      [] ->
        {:error, :station_empty}

      stations ->
        station_number = Integer.mod(station_number, length(stations))

        if video = Enum.at(stations, station_number) do
          {:ok,
           %Station{
             name: Atom.to_string(sub_theme),
             video_id: video["video_id"],
             position: station_number,
             start_seconds: playback_start(video)
           }}
        else
          {:error, :video_not_found}
        end
    end
  end

  defp videos(theme, sub_theme) do
    with true <- theme in [:seasons, :vibes],
         true <- sub_theme in (@seasons ++ @vibes),
         %{theme: stored_theme, videos: videos} <-
           Cafe.Curation.get_playlist(Atom.to_string(sub_theme)),
         true <- stored_theme == Atom.to_string(theme) do
      Enum.map(videos, &Cafe.Curation.Video.to_map(&1))
    else
      _ -> nil
    end
  end

  @doc "Returns the intro offset, or a clock-based position for recordings that join in progress."
  def playback_start(video, now \\ System.system_time(:second)) do
    start = Map.get(video, "start_seconds", 0)
    duration = Map.get(video, "duration_seconds", 0)

    if video["tune_in"] == true && video["live"] != true && duration > start + 10 do
      start + Integer.mod(now, duration - start - 10)
    else
      if video["live"] == true, do: 0, else: start
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
