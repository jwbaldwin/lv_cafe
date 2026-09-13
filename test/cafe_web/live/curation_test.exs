defmodule CafeWeb.CurationTest do
  use CafeWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Cafe.{Curation, Repo, Stations}
  alias Cafe.Curation.Feedback
  alias CafeWeb.AdminAuth

  setup do
    Code.eval_file("priv/repo/seeds.exs")
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
    before = Stations.get_station!("cozy")
    Application.put_env(:cafe, :admin_password, "different-admin-password")
    render_hook(view, "remove", %{"id" => hd(before.videos).video_id})
    assert_redirect(view, "/admin/login")
    assert Stations.get_station!("cozy").videos == before.videos
  end

  test "visitor theme suggestion persists and is visible only in the admin inbox", %{conn: conn} do
    {:ok, view, _} =
      live(
        put_connect_params(conn, %{"preferences" => %{"theme" => "vibes", "sub_theme" => "cozy"}}),
        "/?feedback=open"
      )

    view
    |> form("#feedback-form", feedback: %{message: "I would love a pirate theme"})
    |> render_submit()

    assert render(view) =~ "sent to the inbox"

    assert [
             %Feedback{
               message: "I would love a pirate theme",
               source: "visitor",
               station_name: "cozy",
               video_id: "cEn4c9JDy8A"
             }
           ] =
             Curation.list_feedback()

    {:ok, inbox, html} = live(admin_conn(build_conn()), "/admin")
    assert html =~ "I would love a pirate theme"
    entry = hd(Curation.list_feedback())

    assert has_element?(
             inbox,
             "#feedback-#{entry.id} .curation-feedback-context",
             "Playing video"
           )

    refute has_element?(inbox, "#accept-#{entry.id}")
    refute has_element?(inbox, "#inbox-export", entry.message)
    assert has_element?(inbox, "button[data-copy-inbox][disabled]")
    inbox |> element("#feedback-#{entry.id} button", "Include for Codex") |> render_click()
    assert Repo.get!(Feedback, entry.id).status == "included"
    assert Repo.get!(Feedback, entry.id).admin_note == nil
    assert has_element?(inbox, "#inbox-export", entry.message)
    assert has_element?(inbox, "#inbox-export", "Playing video:")
    {:ok, reloaded, _} = live(admin_conn(build_conn()), "/admin?view=inbox&status=dismissed")
    assert has_element?(reloaded, "#inbox-export", entry.message)
    refute has_element?(inbox, "#feedback-#{entry.id}")
    inbox |> form("#inbox-filter", status: "included") |> render_change()
    assert has_element?(inbox, "#feedback-#{entry.id} button[aria-pressed=true]")
    inbox |> element("#feedback-#{entry.id} button", "Include for Codex") |> render_click()
    assert Repo.get!(Feedback, entry.id).status == "open"
    refute has_element?(inbox, "#inbox-export", entry.message)
    inbox |> form("#inbox-filter", status: "open") |> render_change()
    assert has_element?(inbox, "#feedback-#{entry.id} button[aria-pressed=false]")
    inbox |> element("#feedback-#{entry.id} button", "Include for Codex") |> render_click()
    inbox |> form("#inbox-filter", status: "included") |> render_change()

    inbox |> element("#feedback-#{entry.id} button", "Dismiss") |> render_click()
    assert Repo.get!(Feedback, entry.id).status == "dismissed"
    refute has_element?(inbox, "#inbox-export", entry.message)
    inbox |> form("#inbox-filter", status: "dismissed") |> render_change()
    inbox |> element("#feedback-#{entry.id} button", "Include for Codex") |> render_click()
    assert Repo.get!(Feedback, entry.id).status == "included"

    {:ok, _, public} =
      live(
        put_connect_params(build_conn(), %{
          "preferences" => %{"theme" => "vibes", "sub_theme" => "cozy"}
        }),
        "/"
      )

    refute public =~ "Consider sea shanties"
  end

  test "admin sections keep the selected station and clear preview state", %{conn: conn} do
    {:ok, view, _} = live(admin_conn(conn), "/admin?station=cozy")
    assert has_element?(view, "section[aria-label='Feedback inbox'][hidden]")
    render_hook(view, "preview", %{"id" => "cEn4c9JDy8A"})
    assert_push_event(view, "preview_video", %{video_id: "cEn4c9JDy8A"})

    render_hook(view, "player_verified", %{
      "video_id" => "cEn4c9JDy8A",
      "title" => "Cozy",
      "live" => true,
      "duration_seconds" => 0
    })

    assert has_element?(view, "button[phx-click='save_verification']")
    view |> element("nav[aria-label='Admin sections'] a", "Inbox") |> render_click()
    assert_patch(view, "/admin?view=inbox&station=cozy&status=open")
    assert has_element?(view, "section[aria-label='Stations'][hidden]")
    refute has_element?(view, "section[aria-label='Feedback inbox'][hidden]")
    refute has_element?(view, "button[phx-click='save_verification']")
    view |> form("#inbox-filter", status: "included") |> render_change()
    assert_patch(view, "/admin?view=inbox&station=cozy&status=included")
  end

  test "legacy feedback URL opens the player widget", %{conn: conn} do
    assert conn |> get("/feedback") |> redirected_to() == "/?feedback=open"
  end

  test "widget enforces its limit and uses current server context", %{conn: conn} do
    conn =
      put_connect_params(conn, %{"preferences" => %{"theme" => "vibes", "sub_theme" => "cozy"}})

    {:ok, view, _} = live(conn, "/?feedback=open")

    view
    |> form("#feedback-form", feedback: %{message: String.duplicate("a", 256)})
    |> render_submit()

    assert render(view) =~ "Enter 1–255 characters"
    assert Curation.list_feedback() == []
    view |> form("#feedback-form", feedback: %{message: "   "}) |> render_submit()
    assert Curation.list_feedback() == []
    send(view.pid, {:change_video, 1, 50})
    assert_push_event(view, "changeVideo", %{video_id: "MYPVQccHhAQ"})

    view
    |> element("#feedback-form")
    |> render_submit(%{
      "feedback" => %{
        "message" => String.duplicate("a", 255),
        "video_id" => "forged",
        "station_name" => "winter",
        "source" => "admin"
      }
    })

    assert [%Feedback{video_id: "MYPVQccHhAQ", station_name: "cozy", source: "visitor"}] =
             Curation.list_feedback()
  end

  test "admin can add a video and leave feedback from the same app", %{conn: conn} do
    {:ok, view, _} = live(admin_conn(conn), "/admin")
    view |> form("#add-video", url: "https://youtu.be/vIlzvUsB6H0") |> render_submit()
    assert List.last(Stations.get_station!("cozy").videos).video_id == "vIlzvUsB6H0"
    view |> form("#note-vIlzvUsB6H0", message: "Good scene, find more like it") |> render_submit()
    assert [%Feedback{source: "admin", video_id: "vIlzvUsB6H0"}] = Curation.list_feedback()
  end

  test "a removed current video is replaced for an already connected listener", %{conn: conn} do
    conn =
      put_connect_params(conn, %{"preferences" => %{"theme" => "vibes", "sub_theme" => "cozy"}})

    {:ok, listener, _} = live(conn, "/")
    station = Stations.get_station!("cozy")
    assert {:ok, updated} = Stations.remove_video(station, hd(station.videos).video_id)
    next = hd(updated.videos).video_id
    assert_push_event(listener, "changeVideo", %{video_id: ^next})
  end

  test "stale station edits reload the latest version without overwriting it", %{conn: conn} do
    {:ok, first, _} = live(admin_conn(conn), "/admin?station=cozy")
    {:ok, second, _} = live(admin_conn(build_conn()), "/admin?station=cozy")
    first |> form("#add-video", url: "https://youtu.be/vIlzvUsB6H0") |> render_submit()
    second |> form("#add-video", url: "https://youtu.be/abcdefghijk") |> render_submit()
    assert render(second) =~ "This station changed in another browser"
    station = Stations.get_station!("cozy")
    assert Enum.any?(station.videos, &(&1.video_id == "vIlzvUsB6H0"))
    refute Enum.any?(station.videos, &(&1.video_id == "abcdefghijk"))
  end
end
