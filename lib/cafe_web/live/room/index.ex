defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  alias Cafe.Stations

  def mount(params, session, socket) do
    socket =
      socket
      |> assign(:title, nil)
      |> assign(:info_panel, false)
      |> assign(:feedback_initial_open, params["feedback"] == "open")
      |> assign(:admin_token, session["admin_token"])
      |> assign(:presences, 0)
      |> assign(:volume, 50)
      |> assign(:playing, false)
      |> assign(:muted, false)
      |> assign(:listener_counts, %{})
      |> assign(:failed_videos, MapSet.new())
      |> assign(:preferences, init_preferences(socket))

    socket =
      if connected?(socket) do
        # Subscribe before loading so an edit during the read cannot be missed.
        Phoenix.PubSub.subscribe(Cafe.PubSub, "stations")
        catalog = Map.new(Stations.list_stations(), &{&1.name, &1})
        station = selected_station(catalog, socket.assigns.preferences)

        socket =
          assign(socket, catalog: catalog, station: station, playback: playback(station, 0))

        session_id = session["session_id"] || Ecto.UUID.generate()
        if station, do: CafeWeb.Presence.track_user(station.name, session_id)
        Phoenix.PubSub.subscribe(Cafe.PubSub, "listeners")

        socket
        |> assign(:session_id, session_id)
        |> refresh_presence()
      else
        socket
      end

    {:ok, socket}
  end

  defp selected_station(catalog, preferences) do
    name = Atom.to_string(preferences.sub_theme)
    category = Atom.to_string(preferences.theme)

    case Map.get(catalog, name) do
      %{category: ^category} = station -> station
      _ -> catalog |> Map.values() |> Enum.sort_by(&{&1.category, &1.name}) |> List.first()
    end
  end

  defp playback(nil, _position), do: nil

  defp playback(station, position) do
    case Stations.select_video(station, position) do
      {:ok, playback} -> playback
      {:error, _} -> nil
    end
  end

  def render(assigns) do
    ~H"""
    <div
      id="home"
      phx-hook="Preferences"
      class="flex flex-col items-stretch justify-between fixed inset-0 overflow-hidden p-12"
    >
      <%= if !@preferences do %>
        <div class="flex items-center justify-center h-screen">
          <div class="animate-pulse flex flex-col items-center gap-4">
            <div class="w-12 h-12 border-4 border-primary rounded-full border-t-transparent animate-spin">
            </div>
          </div>
        </div>
      <% else %>
        <%= if @station && @playback do %>
          <CafeWeb.Effects.effect effect={@preferences.sub_theme} />
          <.live_component module={CafeWeb.RoomStats} id="stats" presences={@presences} />
          <.live_component
            module={CafeWeb.ThemeSwitcher}
            preferences={@preferences}
            listener_counts={@listener_counts}
            id="theme-switcher"
          />
          <.live_component module={CafeWeb.PomodoroTimer} id="pomodoro-timer" />
          <.info_panel id="info-panel" info_panel={@info_panel} />
          <.live_component
            module={CafeWeb.FeedbackWidget}
            id="feedback-widget"
            station={@station}
            playback={@playback}
            session_id={@session_id}
            admin_token={@admin_token}
            initial_open={@feedback_initial_open}
          />
          <.live_component
            module={CafeWeb.Components.PlayerControls}
            title={@title}
            position={@playback.position}
            volume={@volume}
            playing={@playing}
            muted={@muted}
            id="controls"
          />
          <div
            class="yt-wrapper fixed inset-0 z-0 overflow-hidden bg-black"
            id="youtube-player-container"
            phx-hook="YouTubePlayer"
            data-video-id={@playback.video_id}
            data-start-seconds={@playback.start_seconds}
            phx-update="ignore"
          >
            <div class="pointer-events-none absolute left-1/2 top-1/2 aspect-video h-[56.25vw] min-h-full w-[177.78vh] min-w-full -translate-x-1/2 -translate-y-1/2">
              <div
                id="youtube-player"
                class="h-full w-full"
              >
              </div>
            </div>
          </div>
        <% else %>
          <p role="status">No stations are available yet.</p>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp info_panel(assigns) do
    ~H"""
    <div class="absolute top-0 right-0 py-8 px-12 z-[2] text-white text-shadow-green text-sm text-right">
      <div>
        <button phx-click="toggle_info_panel" class="p-2 text-white svg-shadow-red">
          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path
              d="M12 16V11M12.5 8C12.5 8.27614 12.2761 8.5 12 8.5C11.7239 8.5 11.5 8.27614 11.5 8M12.5 8C12.5 7.72386 12.2761 7.5 12 7.5C11.7239 7.5 11.5 7.72386 11.5 8M12.5 8H11.5M22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12Z"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </button>
      </div>
      <div
        :if={@info_panel}
        phx-mounted={CafeWeb.AsciiFrame.enter()}
        phx-remove={CafeWeb.AsciiFrame.exit()}
        class="fixed right-4 top-24 ascii-surface info-panel"
      >
        <CafeWeb.AsciiFrame.border />
        <.link navigate="https://x.com/jwbaldwin" class="text-white">@jwbaldwin</.link>
        <dl class="info-panel-shortcuts">
          <%= for {key, label} <- [
            {"[space]", "pause/play"},
            {"[m]", "mute/unmute"},
            {"[t]", "change vibe"},
            {"[p]", "pomodoro"},
            {"[f]", "feedback"},
            {"[←][→]", "prev/next"},
            {"[↑][↓]", "volume"}
          ] do %>
            <dt>{key}</dt><dd>{label}</dd>
          <% end %>
        </dl>
      </div>
    </div>
    """
  end

  def handle_info({:station_updated, station}, socket) do
    previous = Map.get(socket.assigns.catalog, station.name)

    if previous && previous.lock_version >= station.lock_version do
      {:noreply, socket}
    else
      socket = assign(socket, :catalog, Map.put(socket.assigns.catalog, station.name, station))

      if socket.assigns.station && socket.assigns.station.name == station.name do
        current = socket.assigns.playback

        position =
          if current,
            do:
              Enum.find_index(station.videos, &(&1.video_id == current.video_id)) ||
                current.position,
            else: 0

        next = playback(station, position)
        socket = assign(socket, :station, station)

        # Reordering/metadata edits preserve playback; removal selects a replacement.
        socket =
          if current && next && next.video_id == current.video_id,
            do: assign(socket, :playback, next),
            else: socket |> assign(:failed_videos, MapSet.new()) |> change_video(next)

        {:noreply, socket}
      else
        {:noreply, socket}
      end
    end
  end

  def handle_info(:listeners_changed, socket), do: {:noreply, refresh_presence(socket)}

  def handle_info({:change_video, position, _current_volume}, socket) do
    {:noreply,
     socket
     |> assign(:failed_videos, MapSet.new())
     |> change_video(playback(socket.assigns.station, position))}
  end

  def handle_info({:change_theme, theme, sub_theme}, socket) do
    station = Map.get(socket.assigns.catalog, sub_theme)

    if station && station.category == theme do
      previous = socket.assigns.station
      socket = set_preference(socket, theme, sub_theme)

      if !previous || station.name != previous.name do
        if previous,
          do: CafeWeb.Presence.untrack(self(), previous.name, socket.assigns.session_id)

        CafeWeb.Presence.track_user(station.name, socket.assigns.session_id)
      end

      {:noreply,
       socket
       |> assign(station: station, failed_videos: MapSet.new())
       |> change_video(playback(station, 0))
       |> refresh_presence()}
    else
      {:noreply, socket}
    end
  end

  defp refresh_presence(socket) do
    counts = CafeWeb.Presence.list_all_listener_counts()
    name = if socket.assigns.station, do: socket.assigns.station.name
    assign(socket, listener_counts: counts, presences: Map.get(counts, name, 0))
  end

  defp change_video(socket, nil) do
    socket
    |> assign(playback: nil, playing: false, title: "no videos available — try another vibe")
    |> push_event("playerUnavailable", %{})
  end

  defp change_video(socket, playback) do
    socket
    |> assign(playback: playback, title: nil)
    |> push_event("changeVideo", %{
      video_id: playback.video_id,
      start_seconds: playback.start_seconds,
      volume: socket.assigns.volume
    })
  end

  def handle_event("toggle_info_panel", _params, socket) do
    {:noreply, assign(socket, :info_panel, !socket.assigns.info_panel)}
  end

  def handle_event(
        "player_state",
        %{"playing" => playing, "muted" => muted, "volume" => volume},
        socket
      )
      when is_boolean(playing) and is_boolean(muted) and is_number(volume) do
    {:noreply,
     assign(socket, playing: playing, muted: muted, volume: round(max(0, min(100, volume))))}
  end

  def handle_event("player_ready", %{"video_id" => id, "title" => title}, socket)
      when id == socket.assigns.playback.video_id do
    {:noreply, assign(socket, title: String.trim(title), failed_videos: MapSet.new())}
  end

  def handle_event("player_ready", _params, socket), do: {:noreply, socket}

  def handle_event("player_status", %{"video_id" => id, "message" => message}, socket)
      when id == socket.assigns.playback.video_id do
    {:noreply, assign(socket, :title, message)}
  end

  def handle_event("player_status", _params, socket), do: {:noreply, socket}

  def handle_event("player_ended", %{"video_id" => id}, socket)
      when id == socket.assigns.playback.video_id do
    {:noreply,
     change_video(socket, playback(socket.assigns.station, socket.assigns.playback.position + 1))}
  end

  def handle_event("player_ended", _params, socket), do: {:noreply, socket}

  def handle_event("player_error", %{"video_id" => id}, socket)
      when id == socket.assigns.playback.video_id do
    failed = MapSet.put(socket.assigns.failed_videos, id)
    socket = assign(socket, :failed_videos, failed)

    count = length(socket.assigns.station.videos)

    next =
      Enum.find_value(1..count, fn offset ->
        candidate = playback(socket.assigns.station, socket.assigns.playback.position + offset)
        if !MapSet.member?(failed, candidate.video_id), do: candidate
      end)

    if next do
      {:noreply, change_video(socket, next)}
    else
      {:noreply,
       socket
       |> assign(playing: false, title: "no videos available — try another vibe")
       |> push_event("playerUnavailable", %{})}
    end
  end

  def handle_event("player_error", _params, socket), do: {:noreply, socket}
end
