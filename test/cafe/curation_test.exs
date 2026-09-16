defmodule Cafe.CurationTest do
  use Cafe.DataCase

  alias Cafe.{Curation, Repo, Stations}
  alias Cafe.Curation.Feedback

  setup do
    Code.eval_file("priv/repo/seeds.exs")
    :ok
  end

  test "feedback stores station context and protects visitor fields" do
    assert {:ok, feedback} =
             Curation.submit_feedback(%{
               "message" => "A pirate theme please",
               "kind" => "theme",
               "station_name" => "cozy",
               "video_id" => "vIlzvUsB6H0",
               "source" => "admin",
               "status" => "reviewed",
               "admin_note" => "forged"
             })

    assert %Feedback{
             source: "visitor",
             status: "open",
             station_name: "cozy",
             video_id: "vIlzvUsB6H0",
             admin_note: nil
           } = feedback
  end

  test "player feedback uses only the server supplied station and video context" do
    assert {:ok, feedback} =
             Curation.submit_player_feedback(
               "Nice atmosphere",
               %{video_id: "vIlzvUsB6H0", station_name: "cozy"},
               "visitor"
             )

    assert feedback.video_id == "vIlzvUsB6H0"
    assert feedback.station_name == "cozy"
    assert feedback.source == "visitor"
  end

  test "accepting a suggestion updates the station and feedback atomically" do
    assert {:ok, feedback} =
             Curation.submit_feedback(%{
               "message" => "Love this scene",
               "kind" => "video",
               "video_id" => "vIlzvUsB6H0",
               "station_name" => "cozy"
             })

    station = Stations.get_station!(:cozy)
    assert {:ok, updated} = Stations.accept_suggestion(feedback.id, station)
    assert List.last(updated.videos).video_id == feedback.video_id
    assert Repo.get!(Feedback, feedback.id).status == "reviewed"

    assert {:ok, duplicate} =
             Curation.submit_feedback(%{
               "message" => "Another suggestion",
               "kind" => "video",
               "video_id" => "vIlzvUsB6H0",
               "station_name" => "cozy"
             })

    assert {:error, _} = Stations.accept_suggestion(duplicate.id, updated)
    assert Repo.get!(Feedback, duplicate.id).status == "open"
  end

  test "notes remain after their video is removed" do
    station = Stations.get_station!(:cozy)
    video = hd(station.videos)

    assert {:ok, note} =
             Curation.submit_feedback(
               %{
                 "message" => "Too lonely",
                 "kind" => "feedback",
                 "video_id" => video.video_id,
                 "station_name" => station.name
               },
               "admin"
             )

    assert {:ok, _} = Stations.remove_video(station, video.video_id)
    assert Repo.get!(Feedback, note.id).message == "Too lonely"
  end

  test "only recognized YouTube hosts and valid IDs are accepted" do
    for url <- [
          "vIlzvUsB6H0",
          "https://youtube.com/watch?v=vIlzvUsB6H0",
          "https://youtube.com/live/vIlzvUsB6H0",
          "https://youtu.be/vIlzvUsB6H0?t=10"
        ] do
      assert Stations.video_id(url) == "vIlzvUsB6H0"
    end

    for url <- [
          "javascript:alert(1)",
          "https://youtube.com.evil.test/watch?v=vIlzvUsB6H0",
          "../bad",
          nil
        ] do
      assert Stations.video_id(url) == nil
    end
  end

  test "review state and admin notes are validated" do
    assert {:ok, feedback} = Curation.submit_feedback(%{"message" => "A useful note"})

    assert {:ok, reviewed} =
             Curation.review_feedback(feedback.id, %{
               "status" => "reviewed",
               "admin_note" => "Keep this context"
             })

    assert reviewed.status == "reviewed"
    assert reviewed.admin_note == "Keep this context"
    assert {:error, _} = Curation.review_feedback(feedback.id, %{"status" => "unknown"})
  end
end
