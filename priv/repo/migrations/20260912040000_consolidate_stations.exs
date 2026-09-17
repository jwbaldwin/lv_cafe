defmodule Cafe.Repo.Migrations.ConsolidateStations do
  use Ecto.Migration

  @moduledoc """
  Consolidates the original row-per-video stations table and the temporary
  playlists catalog into one station table.

  The old stations table was never the source of runtime playback. It is
  nevertheless checked before it is removed so an unexpected nonempty table
  stops the release instead of losing data.
  """

  def up do
    # Keep the legacy-data check and table changes in the same locked transaction.
    repo().query!("LOCK TABLE stations, playlists IN ACCESS EXCLUSIVE MODE")
    assert_legacy_stations_empty!()

    # The old row-per-video table is obsolete. The playlists table is renamed
    # below, preserving playlist ids, videos, lock versions, and timestamps.
    drop table(:stations)
    rename table(:playlists), to: table(:stations)

    rename table(:stations), :theme, to: :category

    # PostgreSQL keeps the old index name when a table is renamed. Give the
    # consolidated table an explicit name for future migration clarity.
    execute("ALTER INDEX IF EXISTS playlists_name_index RENAME TO stations_name_index")

    rename table(:feedback), :playlist_name, to: :station_name
  end

  def down do
    rename table(:feedback), :station_name, to: :playlist_name

    execute("ALTER INDEX IF EXISTS stations_name_index RENAME TO playlists_name_index")

    rename table(:stations), :category, to: :theme

    rename table(:stations), to: table(:playlists)

    # Restore the historical table shape for a rollback. It is intentionally
    # empty; consolidated station data remains in the restored playlists table.
    create table(:stations) do
      add :position, :integer
      add :video_id, :string
      add :name, :string
      timestamps(type: :utc_datetime)
    end
  end

  defp assert_legacy_stations_empty! do
    case repo().query!("SELECT COUNT(*) FROM stations").rows do
      [[0]] ->
        :ok

      [[count]] ->
        raise "cannot consolidate stations: legacy stations table contains #{count} rows; archive or merge them before this migration"
    end
  end
end
