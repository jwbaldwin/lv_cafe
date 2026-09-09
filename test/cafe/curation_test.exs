defmodule Cafe.CurationTest do
  use Cafe.DataCase
  alias Cafe.{Curation, Repo}
  alias Cafe.Curation.Feedback

  test "the migration seeds all ten curated playlists" do
    assert length(Curation.list_playlists()) == 10
    assert length(Curation.get_playlist!("christmas").videos) == 6
    assert hd(Curation.get_playlist!("summer").videos).video_id == "Yr_5jRBH1JY"
  end

  test "updates persist and stale editors cannot overwrite another browser" do
    original = Curation.get_playlist!("cozy")
    id = hd(original.videos).video_id
    assert {:ok, saved} = Curation.update_video(original, id, %{"title" => "Coffee and hoodie"})
    assert hd(Curation.get_playlist!("cozy").videos).title == "Coffee and hoodie"
    assert {:error, :stale} = Curation.remove_video(original, id)
    assert Curation.get_playlist!("cozy").lock_version == saved.lock_version
  end

  test "adds, moves and removes without duplicates or empty playlists" do
    playlist = Curation.get_playlist!("cozy")
    assert {:ok, playlist} = Curation.add_video(playlist, "https://youtu.be/vIlzvUsB6H0")
    assert List.last(playlist.videos).video_id == "vIlzvUsB6H0"
    assert {:error, _} = Curation.add_video(playlist, "vIlzvUsB6H0")
    assert {:ok, playlist} = Curation.move_video(playlist, "vIlzvUsB6H0", -1)
    assert Enum.at(playlist.videos, 2).video_id == "vIlzvUsB6H0"

    playlist =
      Enum.reduce(Enum.drop(playlist.videos, 1), playlist, fn video, p ->
        assert {:ok, updated} = Curation.remove_video(p, video.video_id)
        updated
      end)

    assert {:error, _} = Curation.remove_video(playlist, hd(playlist.videos).video_id)
    assert length(Curation.get_playlist!("cozy").videos) == 1
  end

  test "video settings reject invalid playback positions" do
    playlist = Curation.get_playlist!("cozy")
    video = Enum.at(playlist.videos, 1)
    assert {:error, _} = Curation.update_video(playlist, video.video_id, %{"start_seconds" => -1})

    assert {:error, _} =
             Curation.update_video(playlist, video.video_id, %{
               "duration_seconds" => 0,
               "tune_in" => true
             })
  end

  test "accepting a suggestion and marking it reviewed is atomic" do
    assert {:ok, feedback} =
             Curation.submit_feedback(%{
               "message" => "Love this coffee scene",
               "kind" => "video",
               "url" => "https://youtu.be/vIlzvUsB6H0"
             })

    playlist = Curation.get_playlist!("cozy")
    assert {:ok, updated} = Curation.accept_suggestion(feedback.id, playlist)
    assert List.last(updated.videos).video_id == feedback.video_id
    assert Repo.get!(Feedback, feedback.id).status == "reviewed"

    assert {:ok, duplicate} =
             Curation.submit_feedback(%{
               "message" => "Another suggestion",
               "url" => "vIlzvUsB6H0"
             })

    assert {:error, _} = Curation.accept_suggestion(duplicate.id, updated)
    assert Repo.get!(Feedback, duplicate.id).status == "open"
  end

  test "visitor submissions cannot set admin identity or review state" do
    assert {:ok, feedback} =
             Curation.submit_feedback(%{
               "message" => "A pirate theme please",
               "source" => "admin",
               "status" => "reviewed",
               "admin_note" => "forged"
             })

    assert feedback.source == "visitor"
    assert feedback.status == "open"
    assert feedback.admin_note == nil

    assert {:error, _} =
             Curation.submit_feedback(%{
               "message" => "hey",
               "url" => "https://evil.example/watch?v=vIlzvUsB6H0"
             })
  end

  test "notes remain after their video is removed" do
    playlist = Curation.get_playlist!("cozy")
    video = hd(playlist.videos)

    assert {:ok, note} =
             Curation.submit_feedback(
               %{
                 "message" => "Too lonely",
                 "video_id" => video.video_id,
                 "playlist_name" => playlist.name
               },
               "admin"
             )

    assert {:ok, _} = Curation.remove_video(playlist, video.video_id)
    assert Repo.get!(Feedback, note.id).message == "Too lonely"
  end

  test "only recognized YouTube hosts and valid IDs are accepted" do
    for url <- [
          "vIlzvUsB6H0",
          "https://youtube.com/watch?v=vIlzvUsB6H0",
          "https://youtube.com/live/vIlzvUsB6H0",
          "https://youtu.be/vIlzvUsB6H0?t=10"
        ] do
      assert Curation.video_id(url) == "vIlzvUsB6H0"
    end

    for url <- [
          "javascript:alert(1)",
          "https://youtube.com.evil.test/watch?v=vIlzvUsB6H0",
          "../bad",
          nil
        ] do
      assert Curation.video_id(url) == nil
    end
  end
end
