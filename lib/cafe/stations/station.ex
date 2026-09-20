defmodule Cafe.Stations.Station do
  @moduledoc "The persisted station catalog entry."

  use Ecto.Schema
  import Ecto.Changeset

  alias Cafe.Stations.Video

  schema "stations" do
    field :name, :string
    field :category, :string
    field :shortcut, :string
    field :position, :integer, default: 0
    field :image_url, :string
    field :effect, :string, default: "none"
    field :seed_key, :string
    field :lock_version, :integer, default: 1
    embeds_many :videos, Video, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(station, attrs) do
    changeset =
      station
      |> cast(attrs, [:name, :category, :shortcut, :position, :image_url, :effect])
      |> update_change(:name, &(&1 && String.trim(&1)))
      |> update_change(:category, &(&1 && String.trim(&1)))
      |> update_change(:shortcut, &(&1 && String.downcase(String.trim(&1))))
      |> validate_required([:name, :category, :shortcut, :position, :effect])
      |> validate_format(:shortcut, ~r/^[a-z0-9]$/, message: "use one letter or number")
      |> validate_exclusion(:shortcut, ~w(p f m t h j k l),
        message: "is reserved for player controls"
      )
      |> validate_number(:position, greater_than_or_equal_to: 0)
      |> validate_inclusion(:effect, effects())
      |> validate_length(:image_url, max: 2048)
      |> validate_change(:image_url, &validate_image/2)
      |> unique_constraint(:shortcut)
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

  def effects, do: ~w(none winter autumn summer spring)

  defp validate_image(:image_url, url) do
    uri = URI.parse(url)

    if (uri.scheme == "https" && is_binary(uri.host) && uri.host != "" && is_nil(uri.userinfo)) ||
         (String.starts_with?(url, "/") && !String.starts_with?(url, "//") &&
            !String.contains?(url, "\\")) do
      []
    else
      [image_url: "use an HTTPS URL or a local image path"]
    end
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
