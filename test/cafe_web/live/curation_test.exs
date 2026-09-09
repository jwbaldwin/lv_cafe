defmodule CafeWeb.CurationTest do
  use CafeWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Cafe.Curation
  alias Cafe.Curation.Feedback
  alias CafeWeb.AdminAuth

  setup do
    old = Application.get_env(:cafe, :admin_password)
    Application.put_env(:cafe, :admin_password, "test-only-curation-password")

    on_exit(fn ->
      if old,
        do: Application.put_env(:cafe, :admin_password, old),
        else: Application.delete_env(:cafe, :admin_password)
    end)

    :ok
  end

  defp admin_conn(conn), do: init_test_session(conn, admin_token: AdminAuth.token())

  test "admin is unavailable without a configured password", %{conn: conn} do
    Application.delete_env(:cafe, :admin_password)
    assert conn |> get("/admin/login") |> html_response(503) =~ "hasn’t been configured"
    assert conn |> get("/admin") |> redirected_to() == "/admin/login"
    refute AdminAuth.valid?("forged")
  end

  test "public and forged sessions cannot open the admin LiveView", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(conn, "/admin")
    forged = init_test_session(conn, admin_token: "forged", admin: true)
    assert {:error, {:redirect, %{to: "/admin/login"}}} = live(forged, "/admin")
  end

  test "login renews the session and logout clears it", %{conn: conn} do
    signed = post(conn, "/admin/login", %{"password" => "test-only-curation-password"})
    assert redirected_to(signed) == "/admin"
    assert AdminAuth.valid?(get_session(signed, :admin_token))
    signed_out = signed |> recycle() |> delete("/admin/logout")
    assert get_session(signed_out, :admin_token) == nil
    wrong = post(build_conn(), "/admin/login", %{"password" => "wrong"})
    assert redirected_to(wrong) == "/admin/login"
    assert get_session(wrong, :admin_token) == nil
  end

  test "rotated credentials revoke already connected admin actions", %{conn: conn} do
    {:ok, view, _} = live(admin_conn(conn), "/admin")
    before = Curation.get_playlist!("cozy")
    Application.put_env(:cafe, :admin_password, "different-admin-password")
    render_hook(view, "remove", %{"id" => hd(before.videos).video_id})
    assert_redirect(view, "/admin/login")
    assert Curation.get_playlist!("cozy").videos == before.videos
  end

  test "admin can add a video and leave feedback from the same app", %{conn: conn} do
    {:ok, view, _} = live(admin_conn(conn), "/admin")
    view |> form("#add-video", url: "https://youtu.be/vIlzvUsB6H0") |> render_submit()
    assert List.last(Curation.get_playlist!("cozy").videos).video_id == "vIlzvUsB6H0"
    view |> form("#note-vIlzvUsB6H0", message: "Good scene, find more like it") |> render_submit()
    assert [%Feedback{source: "admin", video_id: "vIlzvUsB6H0"}] = Curation.list_feedback()
  end

  test "a removed current video is replaced for an already connected listener", %{conn: conn} do
    conn =
      put_connect_params(conn, %{"preferences" => %{"theme" => "vibes", "sub_theme" => "cozy"}})

    {:ok, listener, _} = live(conn, "/")
    playlist = Curation.get_playlist!("cozy")
    assert {:ok, updated} = Curation.remove_video(playlist, hd(playlist.videos).video_id)
    next = hd(updated.videos).video_id
    assert_push_event(listener, "changeVideo", %{video_id: ^next})
  end
end
