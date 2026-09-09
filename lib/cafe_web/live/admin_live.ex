defmodule CafeWeb.AdminLive do
  use CafeWeb, :live_view
  alias Cafe.Curation

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket, playlists: Curation.list_playlists(), verification: nil, preview_id: nil)}
  end

  def handle_params(params, _uri, socket) do
    playlist = Curation.get_playlist(params["theme"] || "cozy") || hd(Curation.list_playlists())

    status =
      if params["status"] in ~w(open reviewed dismissed all), do: params["status"], else: "open"

    {:noreply,
     assign(socket, playlist: playlist, status: status, feedback: Curation.list_feedback(status))}
  end

  def handle_event("select", %{"theme" => theme}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin?theme=#{theme}&status=#{socket.assigns.status}")}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/admin?theme=#{socket.assigns.playlist.name}&status=#{status}")}
  end

  def handle_event("add", %{"url" => url}, socket),
    do: finish(socket, Curation.add_video(socket.assigns.playlist, url))

  def handle_event("remove", %{"id" => id}, socket),
    do: finish(socket, Curation.remove_video(socket.assigns.playlist, id))

  def handle_event("move", %{"id" => id, "direction" => direction}, socket)
      when direction in ["-1", "1"],
      do:
        finish(
          socket,
          Curation.move_video(socket.assigns.playlist, id, String.to_integer(direction))
        )

  def handle_event("save_video", %{"_id" => id, "video" => attrs}, socket) do
    attrs = Map.take(attrs, ~w(title start_seconds duration_seconds tune_in))
    finish(socket, Curation.update_video(socket.assigns.playlist, id, attrs))
  end

  def handle_event("preview", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.playlist.videos, &(&1.video_id == id)) do
      nil ->
        {:noreply, socket}

      video ->
        payload = %{
          video_id: id,
          start_seconds: Cafe.Stations.playback_start(Cafe.Curation.Video.to_map(video))
        }

        {:noreply,
         socket
         |> assign(preview_id: id, verification: nil)
         |> push_event("preview_video", payload)}
    end
  end

  def handle_event(
        "player_verified",
        %{"video_id" => id, "title" => title, "live" => live, "duration_seconds" => duration},
        socket
      )
      when is_binary(title) and is_boolean(live) and is_number(duration) do
    if id == socket.assigns.preview_id do
      verification = %{
        "video_id" => id,
        "title" => String.slice(title, 0, 500),
        "live" => live,
        "duration_seconds" => if(live, do: 0, else: trunc(duration)),
        "verified_at" => DateTime.to_iso8601(DateTime.utc_now())
      }

      {:noreply, assign(socket, :verification, verification)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("save_verification", _, socket) do
    case socket.assigns.verification do
      nil ->
        {:noreply, socket}

      data ->
        attrs =
          if data["live"],
            do: Map.merge(data, %{"start_seconds" => 0, "tune_in" => false}),
            else: data

        finish(socket, Curation.update_video(socket.assigns.playlist, data["video_id"], attrs))
    end
  end

  def handle_event("note", %{"_id" => id, "message" => message}, socket) do
    attrs = %{
      "message" => message,
      "video_id" => id,
      "playlist_name" => socket.assigns.playlist.name
    }

    case Curation.submit_feedback(attrs, "admin") do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:feedback, Curation.list_feedback(socket.assigns.status))
         |> put_flash(:info, "Your note is saved in the inbox.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Write a note between 3 and 4000 characters.")}
    end
  end

  def handle_event("review", %{"_id" => id, "review" => attrs}, socket) do
    case Curation.review_feedback(id, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:feedback, Curation.list_feedback(socket.assigns.status))
         |> put_flash(:info, "Review saved.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not save that review.")}
    end
  end

  def handle_event("accept", %{"_id" => id, "theme" => theme}, socket) do
    result = Curation.accept_suggestion(id, Curation.get_playlist!(theme))

    case result do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(
           playlist: Curation.get_playlist!(socket.assigns.playlist.name),
           feedback: Curation.list_feedback(socket.assigns.status)
         )
         |> put_flash(:info, "Video added; suggestion marked reviewed.")}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Could not add this video. It may already be in that playlist."
         )}
    end
  end

  defp finish(socket, {:ok, playlist}) do
    {:noreply,
     socket
     |> assign(:playlist, playlist)
     |> put_flash(:info, "Saved. The playlist is updated for listeners.")
     |> clear_flash(:error)}
  end

  defp finish(socket, {:error, reason}) do
    message =
      case reason do
        :stale ->
          "This playlist changed in another browser. Latest version loaded; please reapply your edit."

        :invalid_url ->
          "Enter a valid YouTube URL or video ID."

        :edge ->
          "This video is already at the edge of the playlist."

        _ ->
          "Could not save: keep at least one video, avoid duplicates, and check the duration and start offset."
      end

    {:noreply,
     socket
     |> assign(:playlist, Curation.get_playlist!(socket.assigns.playlist.name))
     |> put_flash(:error, message)}
  end

  defp feedback_text(entries) do
    Enum.map_join(entries, "\n\n", fn f ->
      "## #{f.playlist_name || "General"} · #{f.kind} · #{f.source} · #{f.status}\n" <>
        if(f.video_id, do: "https://www.youtube.com/watch?v=#{f.video_id}\n", else: "") <>
        f.message <> if(f.admin_note, do: "\nReview: #{f.admin_note}", else: "")
    end)
  end

  def render(assigns) do
    ~H"""
    <main class="curation-shell">
      <header class="curation-header">
        <div>
          <a href="/">← Vibes</a><h1>Your playlists & inbox</h1><p>
            Edits are saved to the app’s database and take effect immediately.
          </p>
        </div>
        <.form for={%{}} action="/admin/logout" method="delete"><button>Sign out</button></.form>
      </header>
      <p :if={Phoenix.Flash.get(@flash, :info)} role="status">{Phoenix.Flash.get(@flash, :info)}</p>
      <p :if={Phoenix.Flash.get(@flash, :error)} role="alert">{Phoenix.Flash.get(@flash, :error)}</p>
      <div class="curation-columns">
        <section>
          <.form for={%{}} phx-change="select" id="theme-select">
            <label>Theme<select name="theme"><option
              :for={p <- @playlists}
              value={p.name}
              selected={p.name == @playlist.name}
            >
              {String.replace(p.name, "_", " ")}
            </option></select></label>
          </.form>
          <article
            :for={{video, index} <- Enum.with_index(@playlist.videos)}
            class="curation-card"
            id={"video-#{video.video_id}"}
          >
            <div class="curation-video-heading">
              <img
                src={"https://i.ytimg.com/vi/#{video.video_id}/mqdefault.jpg"}
                alt={video.title || video.video_id}
                loading="lazy"
              />
              <div>
                <h2>{video.title || video.video_id}</h2><small>{index + 1}/{length(@playlist.videos)} · {if video.live,
                  do: "Live at last check",
                  else:
                    if(video.verified_at, do: "Recording · embed checked", else: "Not yet verified")}</small>
              </div>
            </div>
            <div class="curation-actions">
              <button phx-click="preview" phx-value-id={video.video_id}>Preview</button>
              <button
                phx-click="move"
                phx-value-id={video.video_id}
                phx-value-direction="-1"
                disabled={index == 0}
                aria-label="Move up"
              >↑</button>
              <button
                phx-click="move"
                phx-value-id={video.video_id}
                phx-value-direction="1"
                disabled={index == length(@playlist.videos) - 1}
                aria-label="Move down"
              >↓</button>
              <button
                phx-click="remove"
                phx-value-id={video.video_id}
                disabled={length(@playlist.videos) == 1}
              >Remove</button>
              <a
                href={"https://www.youtube.com/watch?v=#{video.video_id}"}
                target="_blank"
                rel="noopener"
              >YouTube ↗</a>
            </div>
            <details>
              <summary>Edit video settings</summary>
              <.form for={%{}} phx-submit="save_video" id={"settings-#{video.video_id}"}>
                <input type="hidden" name="_id" value={video.video_id} />
                <label>Title<input name="video[title]" value={video.title} maxlength="500" /></label>
                <div class="curation-settings">
                  <label>Intro offset (seconds)<input
                    type="number"
                    min="0"
                    name="video[start_seconds]"
                    value={video.start_seconds}
                  /></label>
                  <label>Duration (seconds)<input
                    type="number"
                    min="0"
                    name="video[duration_seconds]"
                    value={video.duration_seconds}
                  /></label>
                </div>
                <label><input type="hidden" name="video[tune_in]" value="false" /><input
                  type="checkbox"
                  name="video[tune_in]"
                  value="true"
                  checked={video.tune_in}
                  disabled={video.live}
                /> Join recording in progress</label>
                <button type="submit">Save settings</button>
              </.form>
            </details>
            <details>
              <summary>Leave myself feedback</summary>
              <.form for={%{}} phx-submit="note" id={"note-#{video.video_id}"}>
                <input type="hidden" name="_id" value={video.video_id} />
                <label>What should change?<textarea
                  name="message"
                  required
                  minlength="3"
                  maxlength="4000"
                ></textarea></label>
                <button type="submit">Save to inbox</button>
              </.form>
            </details>
          </article>
          <.form for={%{}} phx-submit="add" id="add-video" class="curation-card">
            <h2>Add a video</h2><label>YouTube link or ID<input name="url" required /></label><button type="submit">Add to playlist</button>
          </.form>
        </section>
        <section>
          <div id="admin-preview" phx-hook="AdminPreview" phx-update="ignore" class="curation-card">
            <div id="admin-player"></div><p data-preview-status>
              Select Preview to play and verify a video.
            </p>
          </div>
          <p :if={@verification}>
            Embed played and advanced. {if @verification["live"],
              do: "Live stream detected.",
              else: "Recording duration detected."}
          </p>
          <button :if={@verification} phx-click="save_verification">Save verification</button>
          <h2 class="curation-inbox-title">Suggestions inbox</h2>
          <.form for={%{}} phx-change="filter" id="inbox-filter">
            <label>Show<select name="status"><option
              :for={status <- ~w(open reviewed dismissed all)}
              value={status}
              selected={status == @status}
            >
              {status}
            </option></select></label>
          </.form>
          <p :if={@feedback == []}>No submissions here yet.</p>
          <article :for={entry <- @feedback} id={"feedback-#{entry.id}"} class="curation-card">
            <small>{entry.source} · {entry.kind} · {entry.playlist_name || "General"} · {entry.inserted_at}</small>
            <p class="curation-message">{entry.message}</p>
            <a
              :if={entry.video_id}
              href={"https://www.youtube.com/watch?v=#{entry.video_id}"}
              target="_blank"
              rel="noopener"
            >Suggested / referenced video ↗</a>
            <.form for={%{}} phx-submit="review" id={"review-#{entry.id}"}>
              <input type="hidden" name="_id" value={entry.id} />
              <label>My review<textarea name="review[admin_note]" maxlength="4000">{entry.admin_note}</textarea></label>
              <label>Status<select name="review[status]"><option
                :for={s <- ~w(open reviewed dismissed)}
                value={s}
                selected={entry.status == s}
              >
                {s}
              </option></select></label>
              <button type="submit">Save review</button>
            </.form>
            <.form :if={entry.video_id} for={%{}} phx-submit="accept" id={"accept-#{entry.id}"}>
              <input type="hidden" name="_id" value={entry.id} />
              <label>Add video to<select name="theme"><option
                :for={p <- @playlists}
                value={p.name}
                selected={p.name == @playlist.name}
              >
                {p.name}
              </option></select></label>
              <button type="submit">Add & mark reviewed</button>
            </.form>
          </article>
          <details :if={@feedback != []}>
            <summary>Copy this inbox view for Codex</summary><textarea id="inbox-export" readonly>{feedback_text(@feedback)}</textarea><button
              type="button"
              data-copy-inbox
            >Copy feedback</button>
          </details>
          <p><small>Showing the latest 200 matching submissions.</small></p>
        </section>
      </div>
    </main>
    """
  end
end
