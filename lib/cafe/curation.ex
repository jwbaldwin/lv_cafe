defmodule Cafe.Curation do
  import Ecto.Query
  alias Cafe.Repo
  alias Cafe.Curation.{Feedback, Playlist}

  def list_playlists, do: Repo.all(from p in Playlist, order_by: [p.theme, p.name])
  def get_playlist(name), do: Repo.get_by(Playlist, name: name)
  def get_playlist!(name), do: Repo.get_by!(Playlist, name: name)

  def list_feedback(status \\ "open") do
    query = from f in Feedback, order_by: [desc: f.inserted_at, desc: f.id], limit: 200
    Repo.all(if status == "all", do: query, else: where(query, [f], f.status == ^status))
  end

  def submit_feedback(attrs, source \\ "visitor") do
    url = String.trim(Map.get(attrs, "url", ""))
    attrs = if url == "", do: attrs, else: Map.put(attrs, "video_id", video_id(url) || "invalid")

    %Feedback{source: source}
    |> Feedback.changeset(attrs)
    |> Repo.insert()
  end

  def submit_player_feedback(message, context, source) do
    %Feedback{source: source, video_id: context.video_id, playlist_name: context.playlist_name}
    |> Ecto.Changeset.cast(%{"message" => message}, [:message])
    |> Ecto.Changeset.update_change(:message, &String.trim/1)
    |> Ecto.Changeset.validate_required([:message])
    |> Ecto.Changeset.validate_length(:message, min: 1, max: 255)
    |> Repo.insert()
  end

  def review_feedback(id, attrs) do
    Repo.get!(Feedback, id) |> Feedback.review_changeset(attrs) |> Repo.update()
  end

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

  def video_id(_), do: nil

  def update_video(playlist, id, attrs) do
    videos = dump(playlist)

    if Enum.any?(videos, &(&1["video_id"] == id)) do
      save(
        playlist,
        Enum.map(videos, fn v -> if v["video_id"] == id, do: Map.merge(v, attrs), else: v end)
      )
    else
      {:error, :missing_video}
    end
  end

  def add_video(playlist, url) do
    case video_id(url) do
      nil -> {:error, :invalid_url}
      id -> save(playlist, dump(playlist) ++ [%{"video_id" => id, "title" => id}])
    end
  end

  def remove_video(playlist, id),
    do: save(playlist, Enum.reject(dump(playlist), &(&1["video_id"] == id)))

  def move_video(playlist, id, direction) when direction in [-1, 1] do
    videos = dump(playlist)
    index = Enum.find_index(videos, &(&1["video_id"] == id))

    if index && index + direction >= 0 && index + direction < length(videos) do
      other = index + direction

      save(
        playlist,
        videos
        |> List.replace_at(index, Enum.at(videos, other))
        |> List.replace_at(other, Enum.at(videos, index))
      )
    else
      {:error, :edge}
    end
  end

  def accept_suggestion(id, playlist) do
    case Repo.transaction(fn ->
           feedback = Repo.get!(Feedback, id)

           with {:ok, updated} <- add_video(playlist, feedback.video_id),
                {:ok, _} <- review_feedback(id, %{"status" => "reviewed"}) do
             updated
           else
             {:error, reason} -> Repo.rollback(reason)
           end
         end) do
      {:ok, updated} -> broadcast(updated)
      error -> error
    end
  end

  defp dump(playlist), do: Enum.map(playlist.videos, &Cafe.Curation.Video.to_map(&1))

  defp save(playlist, videos) do
    case Repo.update(Playlist.changeset(playlist, videos)) do
      {:ok, updated} -> if Repo.in_transaction?(), do: {:ok, updated}, else: broadcast(updated)
      error -> error
    end
  rescue
    Ecto.StaleEntryError -> {:error, :stale}
  end

  defp broadcast(playlist) do
    Phoenix.PubSub.broadcast(Cafe.PubSub, "playlists", {:playlist_updated, playlist.name})
    {:ok, playlist}
  end
end
