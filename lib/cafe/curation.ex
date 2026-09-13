defmodule Cafe.Curation do
  @moduledoc """
  Feedback and review context.

  Station catalog ownership lives in `Cafe.Stations`; this module only reads
  and writes feedback records. Suggestion acceptance is coordinated by
  `Cafe.Stations.accept_suggestion/2` so its station edit and feedback review
  share one transaction.
  """

  import Ecto.Query

  alias Cafe.Curation.Feedback
  alias Cafe.Repo

  @doc "Lists feedback by review status, newest first."
  def list_feedback(status \\ "open") do
    query = from f in Feedback, order_by: [desc: f.inserted_at, desc: f.id], limit: 200

    Repo.all(
      case status do
        "all" -> query
        "open" -> where(query, [f], f.status in ["open", "reviewed"])
        _ -> where(query, [f], f.status == ^status)
      end
    )
  end

  @doc "Returns all feedback that was included for Codex, in chronological order."
  def feedback_for_codex do
    Repo.all(from f in Feedback, where: f.status == "included", order_by: [f.inserted_at, f.id])
  end

  @doc "Persists visitor or admin supplied feedback while protecting server fields."
  def submit_feedback(attrs, source \\ "visitor") do
    %Feedback{source: source}
    |> Feedback.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Persists feedback submitted from the current player context."
  def submit_player_feedback(message, context, source) do
    station_name = Map.get(context, :station_name) || Map.get(context, "station_name")
    video_id = Map.get(context, :video_id) || Map.get(context, "video_id")

    %Feedback{source: source, video_id: video_id, station_name: station_name}
    |> Ecto.Changeset.cast(%{"message" => message}, [:message])
    |> Ecto.Changeset.update_change(:message, &String.trim/1)
    |> Ecto.Changeset.validate_required([:message])
    |> Ecto.Changeset.validate_length(:message, min: 1, max: 255)
    |> Repo.insert()
  end

  @doc "Updates an admin review decision or private note."
  def review_feedback(id, attrs) do
    case Repo.get(Feedback, id) do
      nil -> {:error, :feedback_not_found}
      feedback -> Repo.update(Feedback.review_changeset(feedback, attrs))
    end
  end
end
