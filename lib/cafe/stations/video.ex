defmodule Cafe.Stations.Video do
  @moduledoc """
  A video in a station's ordered lineup.

  Videos are embedded in `Cafe.Stations.Station`; their order in the
  embedding is the playback order.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :video_id, :string
    field :title, :string
    field :live, :boolean, default: false
    field :start_seconds, :integer, default: 0
    field :duration_seconds, :integer, default: 0
    field :tune_in, :boolean, default: false
    field :verified_at, :string
  end

  @doc "Converts an embedded video to parameters for an Ecto changeset."
  def to_map(%__MODULE__{} = video) do
    Map.new(__schema__(:fields), &{Atom.to_string(&1), Map.fetch!(video, &1)})
  end

  def to_map(params) when is_map(params), do: params

  def changeset(video, attrs) do
    video
    |> cast(attrs, [
      :video_id,
      :title,
      :live,
      :start_seconds,
      :duration_seconds,
      :tune_in,
      :verified_at
    ])
    |> validate_required([:video_id])
    |> validate_format(:video_id, ~r/\A[A-Za-z0-9_-]{11}\z/)
    |> validate_length(:title, max: 500)
    |> validate_length(:verified_at, max: 40)
    |> validate_number(:start_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 604_800
    )
    |> validate_number(:duration_seconds,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 604_800
    )
    |> validate_start()
  end

  defp validate_start(changeset) do
    start = get_field(changeset, :start_seconds) || 0
    duration = get_field(changeset, :duration_seconds) || 0
    live = get_field(changeset, :live)
    tune_in = get_field(changeset, :tune_in)

    if !live && ((duration > 0 && start >= duration - 10) || (tune_in && duration <= start + 10)) do
      add_error(
        changeset,
        :start_seconds,
        "must leave at least ten seconds; verify duration before joining in progress"
      )
    else
      changeset
    end
  end
end
