defmodule CafeWeb.PageControllerTest do
  use CafeWeb.ConnCase

  test "GET / includes sharing metadata without JavaScript", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    expected = %{
      "og:type" => "website",
      "og:site_name" => "Vibes",
      "og:title" => "Vibes — Good vibes for every occasion",
      "og:url" => "https://vibes.jwbaldwin.com/",
      "og:image" => "https://vibes.jwbaldwin.com/images/vibes-og.jpg",
      "og:image:type" => "image/jpeg",
      "og:image:width" => "1200",
      "og:image:height" => "630",
      "twitter:card" => "summary_large_image"
    }

    for {key, value} <- expected do
      assert meta(html, key) == [value]
    end

    for field <- ~w(title description image image:alt) do
      assert [value] = meta(html, "og:#{field}")
      assert value != ""
      assert meta(html, "twitter:#{field}") == [value]
    end

    assert [_description] = meta(html, "description")
  end

  test "sharing image is served publicly as JPEG", %{conn: conn} do
    conn = get(conn, "/images/vibes-og.jpg")
    assert get_resp_header(conn, "content-type") == ["image/jpeg"]
    assert response(conn, 200) == File.read!("priv/static/images/vibes-og.jpg")
  end

  defp meta(html, key) do
    html
    |> LazyHTML.query("head meta[property='#{key}'], head meta[name='#{key}']")
    |> LazyHTML.attribute("content")
  end
end
