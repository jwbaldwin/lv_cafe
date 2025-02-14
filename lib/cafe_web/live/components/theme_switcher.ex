defmodule CafeWeb.ThemeSwitcher do
  use CafeWeb, :live_component

  @seasons ["spring", "summer", "autumn", "winter"]

  def mount(socket) do
    {:ok,
     socket
     |> assign(:theme, "winter")
     |> assign(:open, true)
     |> assign(:seasons, @seasons)}
  end

  def handle_event("toggle_switcher", _params, socket) do
    {:noreply, assign(socket, :open, !socket.assigns.open)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative block w-full z-[90]">
      <button
        phx-click="toggle_switcher"
        phx-target={@myself}
        class="fixed top-4 right-4 rounded-full bg-white/90 p-2 text-shadow-green text-shadow-green/80 hover:bg-white/80 transition-all z-[90]"
      >
        ( )
      </button>
      <div :if={@open} class="fixed top-0 right-0 w-full h-full bg-black/50 backdrop-blur-sm">
        <div class="flex items-center justify-center h-full">
          <div class="grid grid-cols-2 place-content-evenly gap-12">
            <%= for season <- @seasons do %>
              <div class="rounded-lg hover:ring-2 hover:ring-white/50">
                <img
                  src={"/images/#{season}.jpg"}
                  alt={"#{season} theme"}
                  class="w-32 h-32 object-cover"
                />
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
