defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  alias Cafe.Stations

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:title, nil)
      |> assign(:info_panel, false)
      |> assign(:presences, 0)
      |> assign(:volume, 50)
      |> assign(:playing, false)
      |> assign(:muted, false)
      |> assign(:listener_counts, %{})
      |> assign(:failed_videos, MapSet.new())
      |> assign(:preferences, init_preferences(socket))

    socket =
      if connected?(socket) do
        station = get_station(socket)

        socket = assign(socket, :station, station)
        session_id = session["session_id"] || Ecto.UUID.generate()
        CafeWeb.Presence.track_user(station.name, session_id)
        Phoenix.PubSub.subscribe(Cafe.PubSub, "listeners")
        Phoenix.PubSub.subscribe(Cafe.PubSub, "playlists")

        socket
        |> assign(:session_id, session_id)
        |> refresh_presence()
      else
        socket
      end

    {:ok, socket}
  end

  defp get_station(socket, pos \\ 0) do
    with {:ok, station} <-
           Stations.fetch_station(
             socket.assigns.preferences.theme,
             socket.assigns.preferences.sub_theme,
             pos
           ) do
      station
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
          module={CafeWeb.Components.PlayerControls}
          title={@title}
          position={@station.position}
          volume={@volume}
          playing={@playing}
          muted={@muted}
          id="controls"
        />
        <div
          class="yt-wrapper fixed inset-0 z-0 overflow-hidden bg-black"
          id="youtube-player-container"
          phx-hook="YouTubePlayer"
          data-video-id={@station.video_id}
          data-start-seconds={@station.start_seconds}
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
        <pre class="info-panel-content"><.link navigate="https://x.com/jwbaldwin" class="text-white">@jwbaldwin</.link>

    [space]   pause/play
    [m]  mute/unmute
    [t]  change vibe
    [p]     pomodoro
    [←][→]    prev/next
    [↑][↓]       volume</pre>
      </div>
    </div>
    """
  end

  def handle_info({:playlist_updated, name}, socket) do
    if socket.assigns.station.name == name do
      playlist = Cafe.Curation.get_playlist!(name)

      position =
        Enum.find_index(playlist.videos, &(&1.video_id == socket.assigns.station.video_id)) ||
          socket.assigns.station.position

      station = get_station(socket, position)

      socket =
        if station.video_id == socket.assigns.station.video_id,
          do: assign(socket, :station, station),
          else: socket |> assign(:failed_videos, MapSet.new()) |> change_video(station)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info(:listeners_changed, socket), do: {:noreply, refresh_presence(socket)}

  def handle_info({:change_video, position, _current_volume}, socket) do
    {:noreply,
     socket
     |> assign(:failed_videos, MapSet.new())
     |> change_video(get_station(socket, position))}
  end

  def handle_info({:change_theme, theme, sub_theme}, socket) do
    socket = set_preference(socket, theme, sub_theme)
    station = get_station(socket)

    if station.name != socket.assigns.station.name do
      CafeWeb.Presence.untrack(self(), socket.assigns.station.name, socket.assigns.session_id)
      CafeWeb.Presence.track_user(station.name, socket.assigns.session_id)
    end

    {:noreply,
     socket
     |> assign(:failed_videos, MapSet.new())
     |> change_video(station)
     |> refresh_presence()}
  end

  defp refresh_presence(socket) do
    counts = CafeWeb.Presence.list_all_listener_counts()

    socket
    |> assign(:listener_counts, counts)
    |> assign(:presences, Map.get(counts, socket.assigns.station.name, 0))
  end

  defp change_video(socket, station) do
    socket
    |> assign(:station, station)
    |> assign(:title, nil)
    |> push_event("changeVideo", %{
      video_id: station.video_id,
      start_seconds: station.start_seconds,
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
      when id == socket.assigns.station.video_id do
    {:noreply, assign(socket, title: String.trim(title), failed_videos: MapSet.new())}
  end

  def handle_event("player_ready", _params, socket), do: {:noreply, socket}

  def handle_event("player_status", %{"video_id" => id, "message" => message}, socket)
      when id == socket.assigns.station.video_id do
    {:noreply, assign(socket, :title, message)}
  end

  def handle_event("player_status", _params, socket), do: {:noreply, socket}

  def handle_event("player_ended", %{"video_id" => id}, socket)
      when id == socket.assigns.station.video_id do
    {:noreply, change_video(socket, get_station(socket, socket.assigns.station.position + 1))}
  end

  def handle_event("player_ended", _params, socket), do: {:noreply, socket}

  def handle_event("player_error", %{"video_id" => id}, socket)
      when id == socket.assigns.station.video_id do
    failed = MapSet.put(socket.assigns.failed_videos, id)
    socket = assign(socket, :failed_videos, failed)

    count =
      Stations.station_count(
        socket.assigns.preferences.theme,
        socket.assigns.preferences.sub_theme
      )

    station =
      Enum.find_value(1..count, fn offset ->
        candidate = get_station(socket, socket.assigns.station.position + offset)
        if !MapSet.member?(failed, candidate.video_id), do: candidate
      end)

    if station do
      {:noreply, change_video(socket, station)}
    else
      {:noreply,
       socket
       |> assign(playing: false, title: "no videos available — try another vibe")
       |> push_event("playerUnavailable", %{})}
    end
  end

  def handle_event("player_error", _params, socket), do: {:noreply, socket}
end
