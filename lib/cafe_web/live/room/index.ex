# lib/cafe_web/live/room_live.ex
defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:video_id, "UGzTkPauX8U")

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-stretch justify-between fixed inset-0 overflow-hidden p-12">
      <.live_component module={CafeWeb.RoomStats} id="stats" class="width-full z-10 block" />
      <.live_component
        module={CafeWeb.PlayerControlsComponent}
        id="controls"
        class="width-full z-10 block"
      />
      <div
        class="yt-wrapper pt-32 px-12 pb-48"
        style="position: fixed; inset: 0px; display: flex; align-items: center; justify-content: center; z-index: 0; background: black;"
      >
        <div style="width: 100%; height: 100%; overflow: hidden; display: flex; align-items: center; justify-content: center; border-radius: 8px;">
          <div style="pointer-events: none; z-index: -1; border-radius: 8px; width: 100vw; height: 200vw;">
            <div class="player-container w-full h-full">
              <div
                id="youtube-player"
                phx-hook="YouTubePlayer"
                data-video-id={@video_id}
                class="w-full h-full"
              >
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_info({CafeWeb.Presence, {:join, presence}}, socket) do
    presences = [socket.assigns.presences | presence]
    {:noreply, assign(socket, :presences, presences)}
  end

  def handle_info({CafeWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      presences = Enum.reject(socket.assigns.presences, &(&1.id == presence.id))
      {:noreply, assign(socket, :presences, presences)}
    else
      # If presence still has metas, update it in the list
      presences =
        Enum.map(socket.assigns.presences, fn p ->
          if p.id == presence.id, do: presence, else: p
        end)

      {:noreply, assign(socket, :presences, presences)}
    end
  end

  def handle_event("player_ready", _params, socket) do
    {:noreply, socket}
  end
end
