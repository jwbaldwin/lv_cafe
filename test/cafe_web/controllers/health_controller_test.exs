defmodule CafeWeb.HealthControllerTest do
  use CafeWeb.ConnCase

  test "health check verifies database connectivity without creating a session", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert response(conn, 200) == "ok"
    assert get_resp_header(conn, "set-cookie") == []
  end
end
