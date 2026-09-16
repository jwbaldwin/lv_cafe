# Run with MIX_ENV=test mix run --no-start scripts/verify-station-migration.exs.
# This creates and removes a uniquely named database using the test repo config.
if Mix.env() != :test, do: raise("migration verification requires MIX_ENV=test")

Application.ensure_all_started(:ecto_sql)
Application.ensure_all_started(:postgrex)
Application.load(:cafe)

config =
  Application.fetch_env!(:cafe, Cafe.Repo)
  |> Keyword.put(:database, "cafe_migration_verify_#{System.system_time(:microsecond)}")
  |> Keyword.put(:pool, DBConnection.ConnectionPool)
  |> Keyword.put(:pool_size, 5)
  |> Keyword.put(:log, false)

Application.put_env(:cafe, Cafe.Repo, config)
:ok = Ecto.Adapters.Postgres.storage_up(config)
{:ok, repo} = Cafe.Repo.start_link()
migrations = Application.app_dir(:cafe, "priv/repo/migrations")
old_version = 20_260_909_040_000
new_version = 20_260_912_040_000
assert = fn condition, message -> if !condition, do: raise(message) end
query = &Cafe.Repo.query!/1
previous_cutover = System.get_env("STATIONS_CUTOVER")
System.delete_env("STATIONS_CUTOVER")

try do
  Ecto.Migrator.run(Cafe.Repo, migrations, :up, to: old_version, log: false)

  query.("""
  INSERT INTO playlists (name, theme, videos, lock_version, inserted_at, updated_at)
  VALUES ('cozy', 'vibes', '[{"video_id":"abcdefghijk","title":"An admin edit","live":false,"start_seconds":30,"duration_seconds":600,"tune_in":true,"verified_at":"2026-09-01T00:00:00Z"}]', 7, '2026-08-01', '2026-09-01')
  """)

  query.("""
  INSERT INTO feedback (message, kind, video_id, playlist_name, source, status, admin_note, inserted_at, updated_at)
  VALUES ('Preserve this feedback', 'feedback', 'abcdefghijk', 'cozy', 'visitor', 'included', 'Preserve this note', '2026-08-02', '2026-09-02')
  """)

  original_station =
    query.("SELECT id,name,theme,videos,lock_version,inserted_at,updated_at FROM playlists").rows

  original_feedback =
    query.(
      "SELECT id,message,kind,video_id,playlist_name,source,status,admin_note,inserted_at,updated_at FROM feedback"
    ).rows

  refused_without_cutover =
    try do
      Ecto.Migrator.run(Cafe.Repo, migrations, :up, to: new_version, log: false)
      false
    rescue
      error in RuntimeError -> String.contains?(Exception.message(error), "STATIONS_CUTOVER=true")
    end

  assert.(refused_without_cutover, "populated catalog migrated without an explicit cutover")

  assert.(
    query.("SELECT id,name,theme,videos,lock_version,inserted_at,updated_at FROM playlists").rows ==
      original_station,
    "refused cutover changed curation"
  )

  System.put_env("STATIONS_CUTOVER", "true")

  Ecto.Migrator.run(Cafe.Repo, migrations, :up, to: new_version, log: false)

  assert.(
    query.("SELECT id,name,category,videos,lock_version,inserted_at,updated_at FROM stations").rows ==
      original_station,
    "curated station data changed during migration"
  )

  assert.(
    query.(
      "SELECT id,message,kind,video_id,station_name,source,status,admin_note,inserted_at,updated_at FROM feedback"
    ).rows == original_feedback,
    "feedback changed during migration"
  )

  assert.(
    query.("SELECT to_regclass('public.playlists') IS NULL").rows == [[true]],
    "obsolete table remains"
  )

  Code.eval_file("priv/repo/seeds.exs")

  once =
    query.(
      "SELECT id,name,category,videos,lock_version,inserted_at,updated_at FROM stations ORDER BY name"
    ).rows

  Code.eval_file("priv/repo/seeds.exs")

  assert.(
    query.(
      "SELECT id,name,category,videos,lock_version,inserted_at,updated_at FROM stations ORDER BY name"
    ).rows == once,
    "seed rerun changed the existing catalog"
  )

  assert.(
    query.(
      "SELECT id,name,category,videos,lock_version,inserted_at,updated_at FROM stations WHERE name='cozy'"
    ).rows == original_station,
    "seeds overwrote curated station"
  )

  Ecto.Migrator.run(Cafe.Repo, migrations, :down, step: 1, log: false)

  assert.(
    query.(
      "SELECT id,name,theme,videos,lock_version,inserted_at,updated_at FROM playlists WHERE name='cozy'"
    ).rows == original_station,
    "rollback changed curation"
  )

  assert.(
    query.(
      "SELECT id,message,kind,video_id,playlist_name,source,status,admin_note,inserted_at,updated_at FROM feedback"
    ).rows == original_feedback,
    "rollback changed feedback"
  )

  query.(
    "INSERT INTO stations (name, video_id, position, inserted_at, updated_at) VALUES ('legacy', 'abcdefghijk', 0, now(), now())"
  )

  refused =
    try do
      Ecto.Migrator.run(Cafe.Repo, migrations, :up, to: new_version, log: false)
      false
    rescue
      error in RuntimeError ->
        String.contains?(Exception.message(error), "legacy stations table contains")
    end

  assert.(refused, "nonempty legacy station data was not protected")

  assert.(
    query.("SELECT name,video_id FROM stations").rows == [["legacy", "abcdefghijk"]],
    "legacy row was lost"
  )

  assert.(
    query.(
      "SELECT id,name,theme,videos,lock_version,inserted_at,updated_at FROM playlists WHERE name='cozy'"
    ).rows == original_station,
    "failed migration changed curation"
  )

  IO.puts("Migration preservation, rollback, seed reruns, and legacy-data protection passed")
after
  if previous_cutover,
    do: System.put_env("STATIONS_CUTOVER", previous_cutover),
    else: System.delete_env("STATIONS_CUTOVER")

  GenServer.stop(repo)
  :ok = Ecto.Adapters.Postgres.storage_down(config)
end
