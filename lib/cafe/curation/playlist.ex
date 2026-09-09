defmodule Cafe.Curation.Playlist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "playlists" do
    field :name, :string
    field :theme, :string
    field :lock_version, :integer, default: 1
    embeds_many :videos, Cafe.Curation.Video, on_replace: :delete
    timestamps(type: :utc_datetime)
  end

  def changeset(playlist, videos) do
    changeset = playlist |> cast(%{"videos" => videos}, []) |> cast_embed(:videos, required: true)
    entries = get_field(changeset, :videos, [])
    ids = Enum.map(entries, & &1.video_id)

    changeset =
      cond do
        length(entries) not in 1..100 ->
          add_error(changeset, :videos, "keep between 1 and 100 videos")

        length(Enum.uniq(ids)) != length(ids) ->
          add_error(changeset, :videos, "contains duplicate videos")

        true ->
          changeset
      end

    optimistic_lock(changeset, :lock_version)
  end
end
