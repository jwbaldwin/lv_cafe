defmodule Cafe.Repo.Migrations.AddCuration do
  use Ecto.Migration

  def change do
    create table(:playlists) do
      add :name, :string, null: false
      add :theme, :string, null: false
      add :videos, :map, null: false, default: fragment("'[]'::jsonb")
      add :lock_version, :integer, null: false, default: 1
      timestamps(type: :utc_datetime)
    end

    create unique_index(:playlists, [:name])

    create table(:feedback) do
      add :message, :text, null: false
      add :kind, :string, null: false, default: "feedback"
      add :video_id, :string
      add :playlist_name, :string
      add :source, :string, null: false, default: "visitor"
      add :status, :string, null: false, default: "open"
      add :admin_note, :text
      timestamps(type: :utc_datetime)
    end

    create index(:feedback, [:status, :inserted_at])
  end
end
