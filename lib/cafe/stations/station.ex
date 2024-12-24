defmodule Cafe.Stations.Station do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stations" do
    field :video_id, :string
    field :position, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(station, attrs) do
    station
    |> cast(attrs, [:position, :video_id])
    |> validate_required([:video_id])
  end
end
