defmodule CafeWeb.HealthController do
  use CafeWeb, :controller

  def show(conn, _params) do
    Ecto.Adapters.SQL.query!(Cafe.Repo, "SELECT 1", [])
    text(conn, "ok")
  end
end
