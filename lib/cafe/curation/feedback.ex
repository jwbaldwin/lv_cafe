defmodule Cafe.Curation.Feedback do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feedback" do
    field :message, :string
    field :kind, :string, default: "feedback"
    field :video_id, :string
    field :playlist_name, :string
    field :source, :string, default: "visitor"
    field :status, :string, default: "open"
    field :admin_note, :string
    timestamps(type: :utc_datetime)
  end

  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:message, :kind, :video_id, :playlist_name])
    |> update_change(:message, &String.trim/1)
    |> validate_required([:message, :kind])
    |> validate_length(:message, min: 3, max: 4000)
    |> validate_length(:playlist_name, max: 60)
    |> validate_inclusion(:kind, ~w(feedback video theme))
    |> validate_format(:video_id, ~r/\A[A-Za-z0-9_-]{11}\z/)
  end

  def review_changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:status, :admin_note])
    |> validate_required([:status])
    |> validate_inclusion(:status, ~w(open reviewed included dismissed))
    |> validate_length(:admin_note, max: 4000)
  end
end
