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
        <div id="top-info" class="absolute top-0 left-0 right-0 flex w-full py-8 px-12 z-[2]">
          <.live_component module={CafeWeb.RoomStats} id="stats" presences={@presences} />
          <.live_component
            module={CafeWeb.ThemeSwitcher}
            preferences={@preferences}
            id="theme-switcher"
          />
          <.info_panel id="info-panel" info_panel={@info_panel} />
        </div>
        <.live_component
          module={CafeWeb.Components.PlayerControls}
          title={@title}
          position={@station.position}
          volume={@volume}
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
              <div class="player-container w-full h-full"></div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp info_panel(assigns) do
    ~H"""
    <div class="z-[2] text-white text-shadow-green text-sm text-right">
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
        phx-mounted={
          JS.transition(
            {"ease-out duration-100", "opacity-0 translate-x-full", "opacity-100 translate-x-0"}
          )
        }
        phx-remove={
          JS.transition(
            {"ease-in duration-100", "opacity-100 translate-x-0", "opacity-0 translate-x-full"}
          )
        }
        class="fixed right-4 top-24"
      >
        <pre class="text-gray-300 font-mono">
    +--------------------+
    |         <.link navigate="https://x.com/jwbaldwin" class="text-white">@jwbaldwin</.link> |
    |                    |
    | [space] pause/play |
    |    [m] mute/unmute |
    |    [t] change vibe |
    +--------------------+
    </pre>
      </div>
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

    {:ok, station} =
      Stations.fetch_station(
        String.to_existing_atom(theme),
        String.to_existing_atom(sub_theme),
        0
      )

    {:noreply,
     socket
     |> push_event("changeVideo", %{video_id: station.video_id, volume: socket.assigns.volume})}
  end

  def handle_info({:volume_changed, volume}, socket) do
    {:noreply, assign(socket, :volume, volume)}
  end

  def handle_event("toggle_info_panel", _params, socket) do
    {:noreply, assign(socket, :info_panel, !socket.assigns.info_panel)}
  end

  def handle_event("player_ready", %{"title" => title}, socket) do
    {:noreply, assign(socket, :title, String.trim(title))}
  end
end
