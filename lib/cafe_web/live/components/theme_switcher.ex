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

  def handle_event("select_theme", %{"theme" => theme}, socket) do
    {:noreply, assign(socket, :theme, theme)}
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
        <div class="flex flex-col items-center justify-center h-full">
          <h2 class="-mt-8 pb-4 text-sm font-semibold text-white text-shadow-green">
            Swap your season
          </h2>
          <div class="grid grid-cols-2 place-content-evenly gap-12">
            <%= for season <- @seasons do %>
              <button
                class="text-center group"
                phx-click="select_theme"
                phx-value-theme={season}
                phx-target={@myself}
              >
                <img
                  src={~p"/images/themes/seasons/#{season}/1.png"}
                  alt={"#{season} theme"}
                  class={[
                    "w-40 h-40 object-cover rounded-lg group-hover:ring-2 group-hover:ring-white/50",
                    @theme == season && "ring-2 ring-green-500/80"
                  ]}
                />
                <span class="pt-2 text-xs text-white text-shadow-green">
                  {season}
                </span>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
