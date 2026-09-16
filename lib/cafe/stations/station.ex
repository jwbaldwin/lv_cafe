defmodule Cafe.Stations.Station do
  @moduledoc "The persisted station catalog entry."

  use Ecto.Schema
  import Ecto.Changeset

  alias Cafe.Stations.Video

  schema "stations" do
    field :name, :string
    field :category, :string
    field :lock_version, :integer, default: 1
    embeds_many :videos, Video, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(station, attrs) do
    changeset =
      station
      |> cast(attrs, [:name, :category])
      |> validate_required([:name, :category])
      |> validate_length(:name, max: 60)
      |> validate_length(:category, max: 60)
      |> cast_embed(:videos, required: true)
      |> validate_videos()
      |> unique_constraint(:name)

    # The database default establishes version one for new rows. Ecto's
    # optimistic_lock helper increments before an insert too, so only attach
    # it to persisted snapshots where it guards concurrent edits.
    if station.id, do: optimistic_lock(changeset, :lock_version), else: changeset
  end

  defp validate_videos(changeset) do
    videos = get_field(changeset, :videos, [])
    ids = Enum.map(videos, & &1.video_id)

    cond do
      length(videos) not in 1..100 ->
        add_error(changeset, :videos, "keep between 1 and 100 videos")

      length(Enum.uniq(ids)) != length(ids) ->
        add_error(changeset, :videos, "contains duplicate videos")

      true ->
        changeset
    end
  end
end
