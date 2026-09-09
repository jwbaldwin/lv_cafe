defmodule CafeWeb.AdminSessionController do
  use CafeWeb, :controller
  alias CafeWeb.AdminAuth

  def new(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_status(if AdminAuth.configured?(), do: 200, else: 503)
    |> render(:new, configured: AdminAuth.configured?())
  end

  def create(conn, %{"password" => password}) do
    allowed = Cafe.RateLimit.allow?({:login, conn.remote_ip}, 10, 900)

    if allowed && AdminAuth.password_valid?(password) do
      conn
      |> configure_session(renew: true)
      |> put_session(:admin_token, AdminAuth.token())
      |> redirect(to: "/admin")
    else
      conn
      |> put_flash(:error, "Could not sign in. Check the password or try again later.")
      |> redirect(to: "/admin/login")
    end
  end

  def create(conn, _params), do: redirect(conn, to: "/admin/login")

  def delete(conn, _params) do
    conn |> clear_session() |> configure_session(renew: true) |> redirect(to: "/")
  end
end
