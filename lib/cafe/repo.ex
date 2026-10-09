defmodule Cafe.Repo do
  use Ecto.Repo,
    otp_app: :cafe,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def default_options(_operation) do
    [prefix: config()[:default_prefix]]
  end
end
