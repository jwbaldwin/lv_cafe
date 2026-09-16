defmodule Cafe.Stations do
  @moduledoc """
  The station catalog context.

  Database access is limited to loading and saving station snapshots. Once a
  station is loaded, selection and all playback calculations are pure.
  """

  import Ecto.Query, warn: false

  alias Cafe.Repo
  alias Cafe.Stations.{Playback, Station, Video}

  # Mute, toggle themes, pause/play, and navigation controls are reserved for the UI.
  @global_keys [
    "p",
    "f",
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

  @doc "Loads the complete catalog in stable category/name order."
  def list_stations do
    Repo.all(from s in Station, order_by: [asc: s.category, asc: s.name])
  end

  @doc "Loads one station by its unique name."
  def get_station(name) when is_atom(name), do: get_station(Atom.to_string(name))
  def get_station(name) when is_binary(name), do: Repo.get_by(Station, name: name)
  def get_station(_name), do: nil

  @doc "Loads one station by its unique name or raises when it is missing."
  def get_station!(name) when is_atom(name), do: get_station!(Atom.to_string(name))
  def get_station!(name) when is_binary(name), do: Repo.get_by!(Station, name: name)
  def get_station!(_name), do: raise(Ecto.NoResultsError, queryable: Station)

  @doc "Updates one embedded video's settings using the supplied station snapshot."
  def update_video(%Station{} = station, id, attrs) when is_binary(id) and is_map(attrs) do
    if Enum.any?(station.videos, &(&1.video_id == id)) do
      videos =
        Enum.map(station.videos, fn video ->
          if video.video_id == id,
            do: Map.merge(Video.to_map(video), attrs),
            else: video
        end)

      save_station(station, %{videos: videos})
    else
      {:error, :missing_video}
    end
  end

  def update_video(_station, _id, _attrs), do: {:error, :missing_video}

  @doc "Adds a YouTube video to the end of a station's lineup."
  def add_video(%Station{} = station, url) do
    case video_id(url) do
      nil ->
        {:error, :invalid_url}

      id ->
        videos =
          station.videos ++ [%{"video_id" => id, "title" => id}]

        save_station(station, %{videos: videos})
    end
  end

  def add_video(_station, _url), do: {:error, :invalid_url}

  @doc "Removes a video while preserving the station's nonempty invariant."
  def remove_video(%Station{} = station, id) when is_binary(id) do
    if Enum.any?(station.videos, &(&1.video_id == id)) do
      save_station(station, %{videos: Enum.reject(station.videos, &(&1.video_id == id))})
    else
      {:error, :missing_video}
    end
  end

  def remove_video(_station, _id), do: {:error, :missing_video}

  @doc "Moves a video one position in either direction."
  def move_video(%Station{} = station, id, direction) when direction in [-1, 1] do
    case Enum.find_index(station.videos, &(&1.video_id == id)) do
      nil ->
        {:error, :missing_video}

      index when index + direction < 0 or index + direction >= length(station.videos) ->
        {:error, :edge}

      index ->
        other = index + direction

        videos =
          station.videos
          |> List.replace_at(index, Enum.at(station.videos, other))
          |> List.replace_at(other, Enum.at(station.videos, index))

        save_station(station, %{videos: videos})
    end
  end

  def move_video(_station, _id, _direction), do: {:error, :invalid_direction}

  @doc """
  Accepts a feedback suggestion into a station and marks the feedback reviewed
  in the same transaction. The successful station snapshot is broadcast once
  the transaction commits.
  """
  def accept_suggestion(feedback_id, %Station{} = station) do
    result =
      Repo.transaction(fn ->
        feedback =
          case Repo.get(Cafe.Curation.Feedback, feedback_id) do
            nil -> Repo.rollback(:feedback_not_found)
            feedback -> feedback
          end

        with {:ok, updated} <- add_video(station, feedback.video_id),
             {:ok, _reviewed} <-
               Cafe.Curation.review_feedback(feedback_id, %{"status" => "reviewed"}) do
          updated
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    case result do
      {:ok, updated} ->
        broadcast(updated)
        {:ok, updated}

      error ->
        error
    end
  end

  @doc "Parses a direct YouTube ID or a URL from a recognized YouTube host."
  def video_id(value) when is_binary(value) do
    value = String.trim(value)

    if Regex.match?(~r/\A[A-Za-z0-9_-]{11}\z/, value) do
      value
    else
      uri = URI.parse(value)

      if uri.scheme in ["http", "https"] do
        id =
          cond do
            uri.host in ["youtu.be", "www.youtu.be"] ->
              String.trim(uri.path || "", "/")

            uri.host in ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"] ->
              URI.decode_query(uri.query || "")["v"] ||
                List.last(String.split(uri.path || "", "/"))

            true ->
              nil
          end

        if is_binary(id) && Regex.match?(~r/\A[A-Za-z0-9_-]{11}\z/, id), do: id
      end
    end
  rescue
    ArgumentError -> nil
  end

  def video_id(_value), do: nil

  @doc "Returns the intro offset, or a clock-based position for recordings that join in progress."
  def playback_start(%Video{} = video, now \\ System.system_time(:second)) do
    start = video.start_seconds || 0
    duration = video.duration_seconds || 0

    cond do
      video.live -> 0
      video.tune_in && duration > start + 10 -> start + Integer.mod(now, duration - start - 10)
      true -> start
    end
  end

  @doc "Selects a video by wrapped position without touching the database."
  def select_video(%Station{videos: []}, _position), do: {:error, :station_empty}

  def select_video(%Station{videos: videos}, position)
      when is_list(videos) and is_integer(position) do
    position = Integer.mod(position, length(videos))
    video = Enum.at(videos, position)

    case video.video_id do
      nil ->
        {:error, :video_not_found}

      video_id ->
        {:ok,
         %Playback{
           video_id: video_id,
           position: position,
           start_seconds: playback_start(video)
         }}
    end
  end

  def select_video(%Station{}, _position), do: {:error, :video_not_found}
  def select_video(_station, _position), do: {:error, :station_not_found}

  @doc "Returns the static season names used by the theme picker."
  def get_seasons, do: @seasons

  @doc "Returns the static vibe names used by the theme picker."
  def get_vibes, do: @vibes

  @doc "Returns all static theme names in picker order."
  def all_stations, do: get_seasons() ++ get_vibes()

  @doc """
  Takes all the theme names and returns a map of unique keys for each theme
  with the found key bracketed in the name.

  For example, `spring` may become `[s]pring` while a later collision can
  produce `mo[r]ning_coffee`.
  """
  def get_stations(theme_names) do
    theme_names
    |> Enum.with_index()
    |> Enum.reduce(%{keys: MapSet.new(@global_keys), mapping: %{}}, fn {name, index},
                                                                       %{
                                                                         keys: set,
                                                                         mapping: mapping
                                                                       } ->
      string_name = to_string(name)
      char = get_unique_character(set, string_name, 0, index)
      styled_name = get_styled_name(string_name, char)

      %{
        keys: MapSet.put(set, char),
        mapping: Map.put(mapping, name, %{char: char, name: styled_name})
      }
    end)
    |> then(& &1.mapping)
  end

  defp save_station(%Station{} = station, attrs) do
    attrs =
      if Map.has_key?(attrs, :videos),
        do: Map.update!(attrs, :videos, fn videos -> Enum.map(videos, &Video.to_map/1) end),
        else: attrs

    case Repo.update(Station.changeset(station, attrs)) do
      {:ok, updated} ->
        if Repo.in_transaction?(), do: {:ok, updated}, else: broadcast(updated)

      error ->
        error
    end
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  defp broadcast(station) do
    Phoenix.PubSub.broadcast(Cafe.PubSub, "stations", {:station_updated, station})
    {:ok, station}
  end

  defp get_styled_name(name, char) when is_integer(char), do: "[#{char}] " <> name
  defp get_styled_name(name, char), do: String.replace(name, char, "[#{char}]", global: false)

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
