defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  def mount(params, _session, socket) do
    socket =
      socket
      |> stream(:presences, [])
      |> assign(:video_id, "UGzTkPauX8U")
      |> assign(:playing, false)

    socket =
      if connected?(socket) do
        CafeWeb.Presence.track_user(params["name"], %{id: params["name"]})
        CafeWeb.Presence.subscribe()
        stream(socket, :presences, CafeWeb.Presence.list_online_users())
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <div style="pointer-events: none; z-index: -1; border-radius: 8px; width: 100vw; height: 50vw;">
        <div class="player-container">
          <div
            id="youtube-player"
            phx-hook="YouTubePlayer"
            data-video-id={@video_id}
            class="w-full aspect-video"
          >
          </div>
        </div>
      </div>
      <div class="controls mt-4 flex justify-center space-x-4">
        <%= if @playing do %>
          <button phx-click="pause" class="px-4 py-2 bg-gray-200 rounded">
            Pause
          </button>
        <% else %>
          <button phx-click="play" class="px-4 py-2 bg-gray-200 rounded">
            Play
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_info({CafeWeb.Presence, {:join, presence}}, socket) do
    {:noreply, stream_insert(socket, :presences, presence)}
  end

  def handle_info({CafeWeb.Presence, {:leave, presence}}, socket) do
    if presence.metas == [] do
      {:noreply, stream_delete(socket, :presences, presence)}
    else
      {:noreply, stream_insert(socket, :presences, presence)}
    end
  end

  def handle_event("play", _params, socket) do
    {:noreply, push_event(socket, "playVideo", %{}) |> assign(:playing, true)}
  end

  def handle_event("pause", _params, socket) do
    {:noreply, push_event(socket, "pauseVideo", %{}) |> assign(:playing, false)}
  end

  def handle_event("player_ready", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("player_state_changed", %{"state" => state}, socket) do
    # YouTube states: -1 (unstarted), 0 (ended), 1 (playing), 2 (paused), 3 (buffering), 5 (cued)
    playing = state == 1
    {:noreply, assign(socket, :playing, playing)}
  end
end
