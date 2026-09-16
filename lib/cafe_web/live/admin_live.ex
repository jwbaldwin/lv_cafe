defmodule CafeWeb.AdminLive do
  use CafeWeb, :live_view
  alias Cafe.{Curation, Stations}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, verification: nil, preview_id: nil)}
  end

  def handle_params(params, _uri, socket) do
    stations = Stations.list_stations()

    station =
      Enum.find(stations, &(&1.name == (params["station"] || "cozy"))) || List.first(stations)

    status =
      if params["status"] in ~w(open included dismissed all), do: params["status"], else: "open"

    view = if params["view"] == "inbox", do: "inbox", else: "stations"

    {:noreply,
     socket
     |> assign(
       station: station,
       station_name: if(station, do: station.name, else: "cozy"),
       stations: stations,
       status: status,
       view: view,
       preview_id: nil,
       verification: nil,
       feedback: Curation.list_feedback(status),
       included_feedback: Curation.feedback_for_codex()
     )
     |> push_event("pause_preview", %{})}
  end

  def handle_event("select", %{"station" => name}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin?station=#{name}&status=#{socket.assigns.status}")}
  end

  def handle_event("filter", %{"status" => status}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin?view=inbox&station=#{socket.assigns.station_name}&status=#{status}"
     )}
  end

  def handle_event("add", %{"url" => url}, socket),
    do: finish(socket, Stations.add_video(socket.assigns.station, url))

  def handle_event("remove", %{"id" => id}, socket),
    do: finish(socket, Stations.remove_video(socket.assigns.station, id))

  def handle_event("move", %{"id" => id, "direction" => direction}, socket)
      when direction in ["-1", "1"],
      do:
        finish(
          socket,
          Stations.move_video(socket.assigns.station, id, String.to_integer(direction))
        )

  def handle_event("save_video", %{"_id" => id, "video" => attrs}, socket) do
    attrs = Map.take(attrs, ~w(title start_seconds duration_seconds tune_in))
    finish(socket, Stations.update_video(socket.assigns.station, id, attrs))
  end

  def handle_event("preview", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.station.videos, &(&1.video_id == id)) do
      nil ->
        {:noreply, socket}

      video ->
        payload = %{
          video_id: id,
          start_seconds: Stations.playback_start(video)
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

        finish(socket, Stations.update_video(socket.assigns.station, data["video_id"], attrs))
    end
  end

  def handle_event("note", %{"_id" => id, "message" => message}, socket) do
    attrs = %{
      "message" => message,
      "video_id" => id,
      "station_name" => socket.assigns.station.name
    }

    case Curation.submit_feedback(attrs, "admin") do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:feedback, Curation.list_feedback(socket.assigns.status))
         |> assign(:included_feedback, Curation.feedback_for_codex())
         |> put_flash(:info, "Your note is saved in the inbox.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Write a note between 3 and 4000 characters.")}
    end
  end

  def handle_event("feedback_status", %{"id" => id, "status" => status}, socket)
      when status in ~w(open included dismissed) do
    case Curation.review_feedback(id, %{"status" => status}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:feedback, Curation.list_feedback(socket.assigns.status))
         |> assign(:included_feedback, Curation.feedback_for_codex())
         |> clear_flash(:info)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not update this feedback.")}
    end
  end

  defp finish(socket, {:ok, station}) do
    {:noreply,
     socket
     |> assign(:station, station)
     |> assign(:stations, Stations.list_stations())
     |> put_flash(:info, "Saved. The station is updated for listeners.")
     |> clear_flash(:error)}
  end

  defp finish(socket, {:error, reason}) do
    message =
      case reason do
        :stale ->
          "This station changed in another browser. Latest version loaded; please reapply your edit."

        :invalid_url ->
          "Enter a valid YouTube URL or video ID."

        :edge ->
          "This video is already at the edge of the station."

        _ ->
          "Could not save: keep at least one video, avoid duplicates, and check the duration and start offset."
      end

    {:noreply,
     socket
     |> assign(:station, Stations.get_station!(socket.assigns.station.name))
     |> put_flash(:error, message)}
  end

  defp feedback_status_label("included"), do: "Included for Codex"
  defp feedback_status_label("dismissed"), do: "Dismissed"
  defp feedback_status_label("all"), do: "All"
  defp feedback_status_label(_), do: "New"

  defp feedback_text(entries) do
    Enum.map_join(entries, "\n\n", fn f ->
      "## Feedback on #{f.station_name || "General"}\n" <>
        "From: #{f.source}\nSent: #{DateTime.to_iso8601(f.inserted_at)}\n" <>
        if(f.video_id,
          do: "Playing video: https://www.youtube.com/watch?v=#{f.video_id}\n",
          else: ""
        ) <>
        "\n#{f.message}"
    end)
  end

  def render(assigns) do
    ~H"""
    <main class="curation-shell">
      <header class="curation-header">
        <a href="/" class="curation-brand">Vibes <span> / Admin</span></a>
        <div class="curation-header-actions">
          <a href="/" target="_blank" rel="noopener">Open player ↗</a><.form
            for={%{}}
            action="/admin/logout"
            method="delete"
          >
            <button>Sign out</button>
          </.form>
        </div>
      </header>
      <nav class="curation-tabs" aria-label="Admin sections">
        <.link
          patch={~p"/admin?view=stations&station=#{@station_name}&status=#{@status}"}
          aria-current={if @view == "stations", do: "page"}
        >Stations</.link>
        <.link
          patch={~p"/admin?view=inbox&station=#{@station_name}&status=#{@status}"}
          aria-current={if @view == "inbox", do: "page"}
        >Inbox</.link>
      </nav>
      <p :if={Phoenix.Flash.get(@flash, :info)} class="curation-notice" role="status">
        {Phoenix.Flash.get(@flash, :info)}
      </p>
      <p :if={Phoenix.Flash.get(@flash, :error)} class="curation-notice curation-error" role="alert">
        {Phoenix.Flash.get(@flash, :error)}
      </p>
      <p :if={!@station && @view == "stations"} role="status">No stations are available yet.</p>
      <section :if={@station} hidden={@view != "stations"} aria-label="Stations">
        <div class="curation-page-heading">
          <div>
            <h1>Stations</h1><p>Choose a station, listen, and fine-tune the lineup.</p>
          </div><span class="curation-status">Changes go live when saved</span>
        </div>
        <div class="curation-workspace">
          <aside class="curation-sidebar">
            <h2>Stations</h2>
            <nav aria-label="Stations">
              <.link
                :for={p <- @stations}
                patch={~p"/admin?view=stations&station=#{p.name}&status=#{@status}"}
                aria-current={if p.name == @station_name, do: "page"}
              >
                <span>{String.replace(p.name, "_", " ")}</span><span>{length(
                  if p.name == @station_name, do: @station.videos, else: p.videos
                )}</span>
              </.link>
            </nav>
          </aside>
          <section class="curation-station" aria-label="Selected station">
            <div class="curation-section-heading">
              <h2>{String.replace(@station_name, "_", " ")}</h2><span>{length(@station.videos)} videos · playback order</span>
            </div>
            <details class="curation-add">
              <summary>+ Add a video</summary>
              <.form for={%{}} phx-submit="add" id="add-video">
                <label>YouTube link or ID<input
                  name="url"
                  type="text"
                  placeholder="https://youtube.com/watch?v=…"
                  required
                /></label><button type="submit" class="curation-primary">Add to station</button>
              </.form>
            </details>
            <.video_card
              :for={{video, index} <- Enum.with_index(@station.videos)}
              video={video}
              index={index}
              station={@station}
              preview_id={@preview_id}
            />
          </section>
          <aside class="curation-preview-column" aria-label="Video preview">
            <h2>Preview</h2>
            <p>Play a video to check that it still works.</p>
            <div
              id="admin-preview"
              phx-hook="AdminPreview"
              phx-update="ignore"
              class="curation-preview-player"
            >
              <div id="admin-player"></div><p data-preview-status>
                Select Preview on a video to listen here.
              </p>
            </div>
            <div :if={@verification} class="curation-verification">
              <strong>Playback checked</strong><p>
                {if @verification["live"], do: "This is a live stream.", else: "This is a recording."} Save to update its title and playback details.
              </p><button phx-click="save_verification" class="curation-primary">Save checked details</button>
            </div>
          </aside>
        </div>
      </section>
      <section hidden={@view != "inbox"} class="curation-inbox" aria-label="Feedback inbox">
        <div class="curation-page-heading">
          <div>
            <h1>Inbox</h1><p>
              Include feedback for your next Codex session, or dismiss it.
            </p>
          </div>
        </div>
        <div class="curation-inbox-toolbar">
          <.form for={%{}} phx-change="filter" id="inbox-filter">
            <label>Status<select name="status"><option
              :for={status <- ~w(open included dismissed all)}
              value={status}
              selected={status == @status}
            >
              {feedback_status_label(status)}
            </option></select></label>
          </.form>
          <span>{length(@feedback)} {if length(@feedback) == 1, do: "item", else: "items"}</span>
          <button type="button" data-copy-inbox disabled={@included_feedback == []}>Copy for Codex ({length(
            @included_feedback
          )})</button>
          <textarea
            id="inbox-export"
            class="sr-only"
            readonly
            aria-label="Inbox export"
          >{feedback_text(@included_feedback)}</textarea>
        </div>
        <div :if={@feedback == []} class="curation-empty">
          <h2>{if @status == "open", do: "All caught up", else: "No feedback here"}</h2><p>
            Suggestions sent from the player will appear here for you to review.
          </p>
        </div>
        <.feedback_card
          :for={entry <- @feedback}
          entry={entry}
        />
        <p :if={length(@feedback) == 200} class="curation-limit">
          Showing the latest 200 matching submissions.
        </p>
      </section>
    </main>
    """
  end

  defp video_card(assigns) do
    ~H"""
    <article
      class="curation-card curation-video-card"
      id={"video-#{@video.video_id}"}
    >
      <div class="curation-video-heading">
        <img
          src={"https://i.ytimg.com/vi/#{@video.video_id}/mqdefault.jpg"}
          alt=""
          loading="lazy"
        />
        <div>
          <h3>{@video.title || @video.video_id}</h3><small>{@index + 1}/{length(@station.videos)} · {if @video.live,
            do: "Live at last check",
            else: if(@video.verified_at, do: "Recording · embed checked", else: "Not yet verified")}</small>
        </div>
      </div>
      <div class="curation-actions">
        <button
          phx-click="preview"
          phx-value-id={@video.video_id}
          class="curation-primary"
          aria-pressed={@preview_id == @video.video_id}
        >Preview</button>
        <a
          href={"https://www.youtube.com/watch?v=#{@video.video_id}"}
          target="_blank"
          rel="noopener"
        >YouTube ↗</a>
      </div>
      <details>
        <summary>Video settings & order</summary>
        <div class="curation-actions">
          <button
            phx-click="move"
            phx-value-id={@video.video_id}
            phx-value-direction="-1"
            disabled={@index == 0}
            aria-label="Move up"
          >↑</button>
          <button
            phx-click="move"
            phx-value-id={@video.video_id}
            phx-value-direction="1"
            disabled={@index == length(@station.videos) - 1}
            aria-label="Move down"
          >↓</button>
          <button
            phx-click="remove"
            phx-value-id={@video.video_id}
            disabled={length(@station.videos) == 1}
            class="curation-danger"
          >Remove from station</button>
        </div>
        <.form for={%{}} phx-submit="save_video" id={"settings-#{@video.video_id}"}>
          <input type="hidden" name="_id" value={@video.video_id} />
          <label>Title<input name="video[title]" value={@video.title} maxlength="500" /></label>
          <div class="curation-settings">
            <label>Skip intro · seconds<input
              type="number"
              min="0"
              name="video[start_seconds]"
              value={@video.start_seconds}
            /></label>
            <label>Video length · seconds<input
              type="number"
              min="0"
              name="video[duration_seconds]"
              value={@video.duration_seconds}
            /></label>
          </div>
          <label><input type="hidden" name="video[tune_in]" value="false" /><input
            type="checkbox"
            name="video[tune_in]"
            value="true"
            checked={@video.tune_in}
            disabled={@video.live}
          /> Join recording in progress</label>
          <button type="submit">Save settings</button>
        </.form>
      </details>
      <details>
        <summary>Leave a note</summary>
        <.form for={%{}} phx-submit="note" id={"note-#{@video.video_id}"}>
          <input type="hidden" name="_id" value={@video.video_id} />
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
    """
  end

  defp feedback_card(assigns) do
    ~H"""
    <article id={"feedback-#{@entry.id}"} class="curation-card">
      <div class="curation-feedback-meta">
        <span>{if @entry.source == "admin", do: "Your note", else: "Listener feedback"}</span>
        <span>{feedback_status_label(@entry.status)}</span>
      </div>
      <p class="curation-message">{@entry.message}</p>
      <div class="curation-feedback-context">
        <h3>Feedback metadata</h3>
        <dl>
          <dt>Station</dt><dd>{String.replace(@entry.station_name || "Not recorded", "_", " ")}</dd>
          <dt>Playing video</dt><dd>
            <a
              :if={@entry.video_id}
              href={"https://www.youtube.com/watch?v=#{@entry.video_id}"}
              target="_blank"
              rel="noopener"
            >{@entry.video_id} ↗</a><span :if={!@entry.video_id}>Not recorded</span>
          </dd>
          <dt>Sent</dt><dd>
            <time datetime={DateTime.to_iso8601(@entry.inserted_at)}>{Calendar.strftime(
              @entry.inserted_at,
              "%b %-d, %Y · %H:%M UTC"
            )}</time>
          </dd>
        </dl>
      </div>
      <div class="curation-actions">
        <button
          aria-pressed={to_string(@entry.status == "included")}
          phx-click="feedback_status"
          phx-value-id={@entry.id}
          phx-value-status={if @entry.status == "included", do: "open", else: "included"}
        ><span aria-hidden="true">{if @entry.status == "included", do: "☑", else: "☐"}</span>
        Include for Codex</button>
        <button
          :if={@entry.status != "dismissed"}
          phx-click="feedback_status"
          phx-value-id={@entry.id}
          phx-value-status="dismissed"
        >Dismiss</button>
      </div>
    </article>
    """
  end
end
