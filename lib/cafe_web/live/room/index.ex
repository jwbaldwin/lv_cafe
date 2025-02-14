# lib/cafe_web/live/room_live.ex
defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  def mount(_params, session, socket) do
    station = Cafe.Stations.get_station(0)

    socket =
      socket
      |> assign(:station, station)
      |> assign(:title, nil)
      |> assign(:presences, 0)

    socket =
      if connected?(socket) do
        session_id = session["session_id"] || Ecto.UUID.generate()
        CafeWeb.Presence.track_user(station.video_id, session_id)
        CafeWeb.Presence.subscribe(station.video_id)
        socket
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-stretch justify-between fixed inset-0 overflow-hidden p-12">
      <.live_component module={CafeWeb.RoomStats} id="stats" presences={@presences} />
      <.live_component
        module={CafeWeb.Components.PlayerControls}
        title={@title}
        position={@station.position}
        id="controls"
      />
      <div
        class="yt-wrapper pt-32 px-12 pb-48"
        style="position: fixed; inset: 0px; display: flex; align-items: center; justify-content: center; z-index: 0; background: black;"
      >
        <div style="width: 100%; height: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; border-radius: 8px;">
          <div style="pointer-events: none; z-index: -1; border-radius: 8px; width: 100vw; height: 200vw;">
            <!-- <div class="player-container w-full h-full"> -->
            <!--   <div -->
            <!--     id="youtube-player" -->
            <!--     phx-hook="YouTubePlayer" -->
            <!--     data-video-id={@station.video_id} -->
            <!--     class="w-full h-full" -->
            <!--   > -->
            <!--   </div> -->
            <!-- </div> -->
          </div>
        </div>
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

  def handle_info({:change_video, station}, socket) do
    {:noreply, assign(socket, :station, station)}
  end

  def handle_event("player_ready", %{"title" => title}, socket) do
    {:noreply, assign(socket, :title, String.trim(title))}
  end
end
