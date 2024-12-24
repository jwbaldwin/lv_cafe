defmodule Cafe.Repo.Migrations.CreateStations do
  use Ecto.Migration

  def change do
    create table(:stations) do
      add :position, :integer
      add :video_id, :string

      timestamps(type: :utc_datetime)
    end
  end
end
