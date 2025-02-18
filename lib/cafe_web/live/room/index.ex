defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  alias Cafe.Stations

  def mount(_params, session, socket) do
    socket =
      socket
      |> assign(:title, nil)
      |> assign(:presences, 0)
      |> assign(:preferences, init_preferences(socket))

    socket =
      if connected?(socket) do
        station = get_station(socket)

        socket = assign(socket, :station, station)
        session_id = session["session_id"] || Ecto.UUID.generate()
        CafeWeb.Presence.track_user(station.video_id, session_id)
        CafeWeb.Presence.subscribe(station.video_id)
        socket
      else
        socket
      end

    {:ok, socket}
  end

  defp get_station(socket, pos \\ 0) do
    IO.inspect(socket.assigns.preferences, label: "preferences")

    Stations.get_station(
      socket.assigns.preferences.theme,
      socket.assigns.preferences.sub_theme,
      pos
    )
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
          id="theme-switcher"
        />
        <.live_component
          module={CafeWeb.Components.PlayerControls}
          title={@title}
          position={@station.position}
          id="controls"
        />
        <div
          class="yt-wrapper pt-32 px-12 pb-48"
          id="youtube-player-container"
          phx-update="ignore"
          style="position: fixed; inset: 0px; display: flex; align-items: center; justify-content: center; z-index: 0; background: black;"
        >
          <div style="width: 100%; height: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; border-radius: 8px;">
            <div style="pointer-events: none; z-index: -1; border-radius: 8px; width: 100vw; height: 200vw;">
              <div class="player-container w-full h-full">
                <div
                  id="youtube-player"
                  phx-hook="YouTubePlayer"
                  data-video-id={@station.video_id}
                  class="w-full h-full"
                >
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_info({CafeWeb.Presence, {:join, _session_id}}, socket) do
    {:noreply, update(socket, :presences, &(&1 + 1))}
  end

  def handle_info({CafeWeb.Presence, {:leave, _session_id}}, socket) do
    {:noreply, update(socket, :presences, &(&1 - 1))}
  end

  def handle_info({:change_video, position, current_volume}, socket) do
    station = get_station(socket, position)

    {:noreply,
     socket
     |> push_event("changeVideo", %{video_id: station.video_id, volume: current_volume})
     |> assign(:station, station)}
  end

  def handle_info({:change_theme, theme, sub_theme}, socket) do
    socket = set_preference(socket, theme, sub_theme)
    station = get_station(socket)

    {:noreply,
     socket
     |> push_event("changeVideo", %{video_id: station.video_id, volume: 50})}
  end

  def handle_event("player_ready", %{"title" => title}, socket) do
    {:noreply, assign(socket, :title, String.trim(title))}
  end
end
