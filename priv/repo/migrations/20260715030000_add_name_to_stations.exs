defmodule Cafe.Repo.Migrations.AddNameToStations do
  use Ecto.Migration

  def change do
    alter table(:stations) do
      add :name, :string
    end
  end
end
