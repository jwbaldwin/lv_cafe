# Run with mix run priv/repo/seeds.exs. Existing stations keep their admin edits.

alias Cafe.Repo
alias Cafe.Stations.Station

{stations, _binding} = Code.eval_file(Path.join(__DIR__, "station_seed_data.exs"))

Enum.each(stations, fn attrs ->
  %Station{}
  |> Station.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing, conflict_target: :name)
end)
