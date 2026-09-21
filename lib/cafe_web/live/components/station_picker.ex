defmodule CafeWeb.StationPicker do
  use CafeWeb, :live_component

  def update(assigns, socket) do
    stations = assigns.catalog |> Map.values() |> Enum.sort_by(&{&1.position, &1.id})
    {:ok, socket |> assign(assigns) |> assign(:stations, stations)}
  end

  def handle_event("select_station", %{"id" => id}, socket) do
    send(self(), {:select_station, id})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div id="stations" phx-hook="StationPicker" class="absolute top-8 right-28 z-[90]">
      <button
        phx-click={toggle_picker()}
        id="station-picker-toggle"
        data-station-picker-toggle
        class="p-2 text-white svg-shadow-red z-[90]"
      >
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <g opacity="0.12">
            <path
              d="M2 6.8C2 5.11984 2 4.27976 2.32698 3.63803C2.6146 3.07354 3.07354 2.6146 3.63803 2.32698C4.27976 2 5.11984 2 6.8 2H7.2C8.88016 2 9.72024 2 10.362 2.32698C10.9265 2.6146 11.3854 3.07354 11.673 3.63803C12 4.27976 12 5.11984 12 6.8V22H6.8C5.11984 22 4.27976 22 3.63803 21.673C3.07354 21.3854 2.6146 20.9265 2.32698 20.362C2 19.7202 2 18.8802 2 17.2V6.8Z"
              fill="currentColor"
            />
            <path
              d="M17.5 22C18.8978 22 19.5967 22 20.1481 21.7716C20.8831 21.4672 21.4672 20.8831 21.7716 20.1481C22 19.5967 22 18.8978 22 17.5V15.7398C22 14.2267 20.7733 13 19.2602 13C18.4603 13 17.7004 13.3495 17.1799 13.9568L13.1556 18.6518C12.7278 19.1509 12.5139 19.4004 12.3616 19.6819C12.2264 19.9316 12.1274 20.1993 12.0675 20.4768C12 20.7897 12 21.1183 12 21.7756V22H17.5Z"
              fill="currentColor"
            />
          </g>
          <path
            d="M8 22H17.5C18.8978 22 19.5967 22 20.1481 21.7716C20.8831 21.4672 21.4672 20.8831 21.7716 20.1481C22 19.5967 22 18.8978 22 17.5V17C22 16.07 22 15.605 21.8978 15.2235C21.6204 14.1883 20.8117 13.3796 19.7765 13.1022C19.395 13 18.93 13 18 13V13M12 6.99964L13.1188 5.88079C13.8252 5.17434 14.1784 4.82111 14.5501 4.61598C15.4522 4.11817 16.5467 4.11812 17.4488 4.61586C17.8206 4.82096 18.1738 5.17415 18.8803 5.88055V5.88055C19.5286 6.52882 19.8528 6.85296 20.0513 7.19863C20.5321 8.03603 20.5805 9.0537 20.1813 9.93293C20.0165 10.2959 19.7245 10.6493 19.1406 11.3562L12 20M7.5 17C7.5 17.2761 7.27614 17.5 7 17.5C6.72386 17.5 6.5 17.2761 6.5 17M7.5 17C7.5 16.7239 7.27614 16.5 7 16.5C6.72386 16.5 6.5 16.7239 6.5 17M7.5 17H6.5M12 22V6.8C12 5.11984 12 4.27976 11.673 3.63803C11.3854 3.07354 10.9265 2.6146 10.362 2.32698C9.72024 2 8.88016 2 7.2 2H6.8C5.11984 2 4.27976 2 3.63803 2.32698C3.07354 2.6146 2.6146 3.07354 2.32698 3.63803C2 4.27976 2 5.11984 2 6.8V17.2C2 18.8802 2 19.7202 2.32698 20.362C2.6146 20.9265 3.07354 21.3854 3.63803 21.673C4.27976 22 5.11984 22 6.8 22H12Z"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </button>
      <div
        id="station-picker"
        data-station-picker
        phx-click={hide_picker()}
        class="fixed inset-0 hidden overflow-y-auto bg-black/80"
      >
        <div class="flex min-h-full flex-col items-center px-4 py-16 sm:px-8 sm:py-20">
          <h2 class="pb-4 text-base text-white text-shadow-green">
            pick a station
          </h2>
          <div class="grid grid-cols-2 place-content-center gap-4 sm:grid-cols-3 sm:gap-6 lg:grid-cols-5">
            <button
              :for={station <- @stations}
              id={"station-#{station.id}"}
              class="text-center group"
              phx-click={JS.push("select_station") |> hide_picker()}
              data-station-key={station.shortcut}
              data-station-selected={to_string(@selected_id == station.id)}
              phx-value-id={station.id}
              phx-target={@myself}
            >
              <div class={[
                "h-28 w-28 rounded-lg overflow-hidden bg-zinc-800 group-hover:ring-2 group-hover:ring-white/50 sm:h-32 sm:w-32",
                @selected_id == station.id && "ring-2 ring-green-500/80"
              ]}>
                <img
                  :if={station.image_url}
                  src={station.image_url}
                  alt=""
                  decoding="async"
                  class="h-full w-full object-cover"
                />
                <span
                  :if={!station.image_url}
                  class="flex h-full items-center justify-center text-3xl text-white"
                >♫</span>
              </div>
              <span class="block pt-2 text-xs text-white text-shadow-green">
                [{station.shortcut}] {station.name}
                <span class="inline-block w-1.5 h-1.5 ml-1.5 bg-red-400"></span>
                {Map.get(@listener_counts, to_string(station.id), 0)}
              </span>
              <span class="block text-xs text-white/60">{station.category}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp toggle_picker(js \\ %JS{}) do
    JS.toggle(js,
      to: "#station-picker",
      in: {"ease-out duration-100", "opacity-0", "opacity-100"},
      out: {"ease-in duration-100", "opacity-100", "opacity-0"}
    )
  end

  defp hide_picker(js \\ %JS{}) do
    JS.hide(js,
      to: "#station-picker",
      time: 100,
      transition: {"ease-in duration-100", "opacity-100", "opacity-0"}
    )
  end
end
