defmodule CafeWeb.AdminAuth do
  import Plug.Conn, except: [assign: 3]
  import Phoenix.Controller
  import Phoenix.Component, only: [assign: 3]

  @max_age 43_200

  def configured? do
    password = Application.get_env(:cafe, :admin_password)
    is_binary(password) && byte_size(password) >= 16
  end

  def password_valid?(password) when is_binary(password) do
    configured?() && Plug.Crypto.secure_compare(digest(password), credential_digest())
  end

  def password_valid?(_), do: false

  def token do
    Phoenix.Token.sign(CafeWeb.Endpoint, "admin-session", credential_version())
  end

  def valid?(token) when is_binary(token) do
    with true <- configured?(),
         {:ok, signed_digest} <-
           Phoenix.Token.verify(CafeWeb.Endpoint, "admin-session", token, max_age: @max_age),
         true <- is_binary(signed_digest) do
      Plug.Crypto.secure_compare(signed_digest, credential_version())
    else
      _ -> false
    end
  end

  def valid?(_), do: false

  def init(opts), do: opts

  def call(conn, _opts) do
    if valid?(get_session(conn, :admin_token)) do
      conn |> put_resp_header("cache-control", "no-store")
    else
      conn |> redirect(to: "/admin/login") |> halt()
    end
  end

  def on_mount(:admin, _params, session, socket) do
    token = session["admin_token"]

    if valid?(token) do
      socket =
        socket
        |> assign(:admin_token, token)
        |> Phoenix.LiveView.attach_hook(:admin_expiry, :handle_event, fn _event,
                                                                         _params,
                                                                         socket ->
          if valid?(socket.assigns.admin_token),
            do: {:cont, socket},
            else: {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
        end)
        |> Phoenix.LiveView.attach_hook(:admin_params, :handle_params, fn _params, _uri, socket ->
          if valid?(socket.assigns.admin_token),
            do: {:cont, socket},
            else: {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
        end)

      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/admin/login")}
    end
  end

  defp credential_version do
    :crypto.mac(
      :hmac,
      :sha256,
      CafeWeb.Endpoint.config(:secret_key_base),
      Application.fetch_env!(:cafe, :admin_password)
    )
    |> Base.encode16()
  end

  defp digest(password), do: :crypto.hash(:sha256, password) |> Base.encode16()
  defp credential_digest, do: digest(Application.fetch_env!(:cafe, :admin_password))
end
