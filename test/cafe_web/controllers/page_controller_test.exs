defmodule CafeWeb.PageControllerTest do
  use CafeWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "vibes"
  end
end
