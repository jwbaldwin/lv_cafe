# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Cafe.Repo.insert!(%Cafe.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Cafe.Stations

Stations.create_station(%{video_id: "UGzTkPauX8U", position: 1})
Stations.create_station(%{video_id: "pfiCNAc2AgU", position: 2})
Stations.create_station(%{video_id: "grQl_OaN2BQ", position: 3})
