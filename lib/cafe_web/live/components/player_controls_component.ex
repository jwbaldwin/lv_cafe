defmodule CafeWeb.PlayerControlsComponent do
  use CafeWeb, :live_component

  def mount(socket) do
    {:ok, assign(socket, playing: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative block width-full z-10">
      <%= if @playing do %>
        <button phx-click="pause" phx-target={@myself} class="px-4 py-2 bg-white rounded">
          Pause
        </button>
      <% else %>
        <button phx-click="play" phx-target={@myself} class="px-4 py-2 bg-white rounded">
          Play
        </button>
      <% end %>
      <button phx-click="increase_volume" phx-target={@myself} class="px-4 py-2 bg-white rounded">
        Volume +
      </button>
      <button phx-click="decrease_volume" phx-target={@myself} class="px-4 py-2 bg-white rounded">
        Volume -
      </button>
    </div>
    """
  end

  def handle_event("play", _params, socket) do
    {:noreply, push_event(socket, "playVideo", %{}) |> assign(:playing, true)}
  end

  def handle_event("pause", _params, socket) do
    {:noreply, push_event(socket, "pauseVideo", %{}) |> assign(:playing, false)}
  end

  def handle_event("increase_volume", _params, socket) do
    {:noreply, push_event(socket, "incVolume", %{})}
  end

  def handle_event("decrease_volume", _params, socket) do
    {:noreply, push_event(socket, "decVolume", %{})}
  end

  def handle_event("player_state_changed", %{"state" => state}, socket) do
    # YouTube states: -1 (unstarted), 0 (ended), 1 (playing), 2 (paused), 3 (buffering), 5 (cued)
    playing = state == 1
    {:noreply, assign(socket, :playing, playing)}
  end
end
