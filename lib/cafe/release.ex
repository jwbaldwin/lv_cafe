defmodule Cafe.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :cafe

  def migrate do
    load_app()

    Enum.each(repos(), fn repo ->
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true, prefix: repo.config()[:default_prefix])
        end)
    end)
  end

  @doc "Seeds a freshly migrated database without starting the web endpoint."
  def seed do
    load_app()

    Enum.each(repos(), fn repo ->
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Code.eval_file(Application.app_dir(@app, "priv/repo/seeds.exs"))
        end)
    end)
  end

  def rollback(repo, version) do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(repo, fn repo ->
        Ecto.Migrator.run(repo, :down, to: version, prefix: repo.config()[:default_prefix])
      end)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
