defmodule CafeWeb.Components.PlayerControls do
  use CafeWeb, :live_component

  def mount(socket) do
    {:ok,
     socket
     |> assign(:volume, 50)
     |> assign(:playing, true)
     |> assign(:muted, true)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative block width-full z-[2]">
      <div class="flex items-center">
        <%= if @playing do %>
          <button
            phx-click="pause_click"
            phx-window-keyup="pause_key"
            phx-target={@myself}
            class="px-4 py-2 text-white hover:text-shadow-green text-shadow-green"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 hover:svg-shadow-green svg-shadow-green"
            >
              <path
                d="M2.25 6.25C2.25 4.84987 2.25 4.1498 2.52248 3.61502C2.76217 3.14462 3.14462 2.76217 3.61502 2.52248C4.1498 2.25 4.84987 2.25 6.25 2.25H6.75C8.15013 2.25 8.8502 2.25 9.38498 2.52248C9.85538 2.76217 10.2378 3.14462 10.4775 3.61502C10.75 4.1498 10.75 4.84987 10.75 6.25V17.75C10.75 19.1501 10.75 19.8502 10.4775 20.385C10.2378 20.8554 9.85538 21.2378 9.38498 21.4775C8.8502 21.75 8.15013 21.75 6.75 21.75H6.25C4.84987 21.75 4.1498 21.75 3.61502 21.4775C3.14462 21.2378 2.76217 20.8554 2.52248 20.385C2.25 19.8502 2.25 19.1501 2.25 17.75V6.25Z"
                fill="currentColor"
              />
              <path
                d="M17.25 2.25C15.8499 2.25 15.1498 2.25 14.615 2.52248C14.1446 2.76217 13.7622 3.14462 13.5225 3.61502C13.25 4.1498 13.25 4.84987 13.25 6.25V17.75C13.25 19.1501 13.25 19.8502 13.5225 20.385C13.7622 20.8554 14.1446 21.2378 14.615 21.4775C15.1498 21.75 15.8499 21.75 17.25 21.75H17.75C19.1501 21.75 19.8502 21.75 20.385 21.4775C20.8554 21.2378 21.2378 20.8554 21.4775 20.385C21.75 19.8502 21.75 19.1501 21.75 17.75V6.25C21.75 4.84987 21.75 4.1498 21.4775 3.61502C21.2378 3.14462 20.8554 2.76217 20.385 2.52248C19.8502 2.25 19.1501 2.25 17.75 2.25H17.25Z"
                fill="currentColor"
              />
            </svg>
          </button>
        <% else %>
          <button
            phx-click="play_click"
            phx-window-keyup="play_key"
            phx-target={@myself}
            class="px-4 py-2 text-white hover:text-shadow-green text-shadow-green"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 hover:svg-shadow-green svg-shadow-green"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M10.1186 2.63788C8.5271 1.66527 7.73133 1.17897 7.07571 1.23632C6.50412 1.28632 5.98153 1.57941 5.64081 2.04106C5.25 2.57059 5.25 3.50319 5.25 5.36838V18.6314C5.25 20.4966 5.25 21.4292 5.64081 21.9587C5.98153 22.4204 6.50412 22.7135 7.07571 22.7635C7.73133 22.8208 8.5271 22.3345 10.1186 21.3619L20.9702 14.7304C22.4475 13.8276 23.1861 13.3762 23.438 12.7951C23.6578 12.2877 23.6578 11.712 23.438 11.2047C23.1861 10.6236 22.4475 10.1722 20.9702 9.26939L10.1186 2.63788Z"
                fill="currentColor"
              />
            </svg>
          </button>
        <% end %>
        <div class="station-buttons px-2">
          <button
            phx-click="prev_station"
            phx-target={@myself}
            class="px-2 py-2 text-white hover:text-shadow-green text-shadow-green"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 hover:svg-shadow-green svg-shadow-green"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M2.80048 14.692C1.40694 13.7961 0.710166 13.3482 0.469506 12.7787C0.259227 12.281 0.259227 11.7194 0.469506 11.2218C0.710166 10.6522 1.40694 10.2043 2.80048 9.30844L10.4243 4.40743C11.5003 3.71569 12.0383 3.36983 12.4735 3.30903C13.3466 3.18706 14.1965 3.6511 14.566 4.45145C14.7502 4.85039 14.7502 5.48998 14.7502 6.76918L17.8196 4.79602C19.4255 3.76364 20.2285 3.24745 20.8925 3.29488C21.4711 3.33621 22.0034 3.62677 22.351 4.09117C22.75 4.62409 22.75 5.57866 22.75 7.48779V16.5126C22.75 18.4218 22.75 19.3763 22.351 19.9093C22.0034 20.3737 21.4711 20.6642 20.8925 20.7055C20.2285 20.753 19.4255 20.2368 17.8196 19.2044L14.7502 17.2313C14.7502 18.5104 14.7502 19.15 14.566 19.549C14.1965 20.3493 13.3466 20.8134 12.4735 20.6914C12.0383 20.6306 11.5003 20.2847 10.4243 19.593L2.80048 14.692Z"
                fill="currentColor"
              />
            </svg>
          </button>
          <button
            phx-click="next_station"
            phx-target={@myself}
            class="px-2 py-2 text-white hover:text-shadow-green text-shadow-green"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              class="transform rotate-180 w-4 h-4 hover:svg-shadow-green svg-shadow-green"
            >
              <path
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M2.80048 14.692C1.40694 13.7961 0.710166 13.3482 0.469506 12.7787C0.259227 12.281 0.259227 11.7194 0.469506 11.2218C0.710166 10.6522 1.40694 10.2043 2.80048 9.30844L10.4243 4.40743C11.5003 3.71569 12.0383 3.36983 12.4735 3.30903C13.3466 3.18706 14.1965 3.6511 14.566 4.45145C14.7502 4.85039 14.7502 5.48998 14.7502 6.76918L17.8196 4.79602C19.4255 3.76364 20.2285 3.24745 20.8925 3.29488C21.4711 3.33621 22.0034 3.62677 22.351 4.09117C22.75 4.62409 22.75 5.57866 22.75 7.48779V16.5126C22.75 18.4218 22.75 19.3763 22.351 19.9093C22.0034 20.3737 21.4711 20.6642 20.8925 20.7055C20.2285 20.753 19.4255 20.2368 17.8196 19.2044L14.7502 17.2313C14.7502 18.5104 14.7502 19.15 14.566 19.549C14.1965 20.3493 13.3466 20.8134 12.4735 20.6914C12.0383 20.6306 11.5003 20.2847 10.4243 19.593L2.80048 14.692Z"
                fill="currentColor"
              />
            </svg>
          </button>
        </div>
        <div class="volume-buttons px-2">
          <div id={"volume-bar-#{@id}"} class="flex gap-1 p-1 select-none cursor-pointer">
            <%= for block <- 1..10 do %>
              <div
                class={[
                  "w-3 h-4 rounded-sm",
                  if(block <= div(@volume, 10),
                    do: "bg-white/90",
                    else: "bg-green-800/50"
                  )
                ]}
                phx-click="set_volume"
                phx-value-volume={block * 10}
                phx-target={@myself}
              >
              </div>
            <% end %>
          </div>
        </div>
        <div class="mute-buttons px-2">
          <button
            phx-click="mute_click"
            phx-window-keyup="mute_key"
            phx-target={@myself}
            class="px-2 py-2 text-white hover:text-shadow-green text-shadow-green"
          >
            <svg
              viewBox="0 0 24 24"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              class="w-4 h-4 hover:svg-shadow-green svg-shadow-green"
            >
              <path
                :if={@muted}
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M14.6 3.92722C14.75 4.34048 14.75 5.23753 14.75 7.03162L14.75 16.9689L14.75 16.969C14.75 18.763 14.75 19.6601 14.6 20.0733C14.0304 21.6426 12.1122 22.2234 10.7678 21.2336C10.4137 20.973 9.91616 20.2266 8.92099 18.7338L8.92097 18.7338L8.92096 18.7338C8.64524 18.3202 8.50738 18.1134 8.35218 17.9372C7.7951 17.3046 7.02842 16.8943 6.19304 16.7816C5.96031 16.7503 5.71177 16.7503 5.2147 16.7503L4.87932 16.7503C3.82764 16.7503 3.3018 16.7503 2.88152 16.5946C2.19794 16.3413 1.65894 15.8023 1.4057 15.1187C1.25 14.6985 1.25 14.1726 1.25 13.121L1.25 10.8796C1.25 9.82792 1.25 9.30208 1.4057 8.8818C1.65894 8.19821 2.19794 7.65921 2.88152 7.40597C3.3018 7.25027 3.82764 7.25027 4.87932 7.25027L5.2147 7.25027L5.21471 7.25027C5.71178 7.25027 5.96031 7.25027 6.19304 7.2189C7.02842 7.10629 7.7951 6.69598 8.35218 6.06337C8.50738 5.88712 8.64524 5.68033 8.92097 5.26674L8.92097 5.26673C9.91615 3.77396 10.4137 3.02757 10.7678 2.76691C12.1122 1.77711 14.0304 2.35791 14.6 3.92722ZM17.5304 9.46968C17.2375 9.17679 16.7626 9.17679 16.4697 9.46968C16.1768 9.76257 16.1768 10.2374 16.4697 10.5303L18.4394 12.5L16.4697 14.4697C16.1768 14.7626 16.1768 15.2374 16.4697 15.5303C16.7626 15.8232 17.2375 15.8232 17.5304 15.5303L19.5 13.5607L21.4697 15.5303C21.7626 15.8232 22.2375 15.8232 22.5304 15.5303C22.8233 15.2374 22.8233 14.7626 22.5304 14.4697L20.5607 12.5L22.5304 10.5303C22.8233 10.2374 22.8233 9.76257 22.5304 9.46968C22.2375 9.17679 21.7626 9.17679 21.4697 9.46968L19.5 11.4393L17.5304 9.46968Z"
                fill="currentColor"
              />
              <path
                :if={not @muted}
                fill-rule="evenodd"
                clip-rule="evenodd"
                d="M14.6 3.9271C14.75 4.34036 14.75 5.23741 14.75 7.0315L14.75 16.9688L14.75 16.9688C14.75 18.7629 14.75 19.6599 14.6 20.0732C14.0304 21.6425 12.1122 22.2233 10.7678 21.2335C10.4137 20.9729 9.91616 20.2265 8.92099 18.7337L8.92097 18.7337L8.92096 18.7337C8.64524 18.3201 8.50738 18.1133 8.35218 17.9371C7.7951 17.3044 7.02842 16.8941 6.19304 16.7815C5.96031 16.7501 5.71177 16.7501 5.2147 16.7501L4.87932 16.7501C3.82764 16.7502 3.3018 16.7502 2.88152 16.5945C2.19794 16.3412 1.65894 15.8022 1.4057 15.1186C1.25 14.6983 1.25 14.1725 1.25 13.1208L1.25 10.8795C1.25 9.82779 1.25 9.30196 1.4057 8.88167C1.65894 8.19809 2.19794 7.65909 2.88152 7.40585C3.3018 7.25015 3.82764 7.25015 4.87932 7.25015L5.2147 7.25015L5.21471 7.25015C5.71178 7.25015 5.96031 7.25015 6.19304 7.21878C7.02842 7.10617 7.7951 6.69586 8.35218 6.06324C8.50738 5.887 8.64524 5.6802 8.92097 5.26662L8.92097 5.26661C9.91615 3.77384 10.4137 3.02745 10.7678 2.76679C12.1122 1.77699 14.0304 2.35779 14.6 3.9271ZM18.4164 5.37628C18.0719 5.14625 17.6062 5.23901 17.3761 5.58347C17.1461 5.92794 17.2389 6.39367 17.5833 6.6237C19.1509 7.67051 20.2499 9.66489 20.2499 12C20.2499 14.3351 19.1509 16.3295 17.5833 17.3763C17.2389 17.6063 17.1461 18.072 17.3761 18.4165C17.6062 18.761 18.0719 18.8537 18.4164 18.6237C20.4357 17.2752 21.7499 14.7926 21.7499 12C21.7499 9.20741 20.4357 6.72478 18.4164 5.37628ZM17.4164 9.37629C17.0719 9.14625 16.6062 9.23901 16.3761 9.58348C16.1461 9.92794 16.2389 10.3937 16.5833 10.6237C16.9553 10.8721 17.2499 11.3741 17.2499 12C17.2499 12.6259 16.9553 13.1279 16.5833 13.3763C16.2389 13.6063 16.1461 14.072 16.3761 14.4165C16.6062 14.761 17.0719 14.8537 17.4164 14.6237C18.2401 14.0736 18.7499 13.0833 18.7499 12C18.7499 10.9166 18.2401 9.92635 17.4164 9.37629Z"
                fill="currentColor"
              />
            </svg>
          </button>
        </div>
      </div>
      <div>
        <span class="px-4 text-white text-shadow-green lowercase text-sm">
          {@title}
        </span>
      </div>
    </div>
    """
  end

  def handle_event("play_click", _params, socket) do
    play_video(socket)
  end

  def handle_event("play_key", %{"key" => " ", "value" => ""}, socket) do
    play_video(socket)
  end

  def handle_event("play_key", _, socket) do
    {:noreply, socket}
  end

  def handle_event("pause_click", _params, socket) do
    pause_video(socket)
  end

  def handle_event("pause_key", %{"key" => " ", "value" => ""}, socket) do
    pause_video(socket)
  end

  def handle_event("pause_key", _, socket) do
    {:noreply, socket}
  end

  def handle_event("player_state_changed", %{"state" => state}, socket) do
    # YouTube states: -1 (unstarted), 0 (ended), 1 (playing), 2 (paused), 3 (buffering), 5 (cued)
    playing = state == 1
    {:noreply, assign(socket, :playing, playing)}
  end

  def handle_event("next_station", _params, socket) do
    send(self(), {:change_video, socket.assigns.position + 1, socket.assigns.volume})

    {:noreply, socket}
  end

  def handle_event("prev_station", _params, socket) do
    send(self(), {:change_video, socket.assigns.position - 1, socket.assigns.volume})
    {:noreply, socket}
  end

  def handle_event("set_volume", %{"volume" => volume}, socket) do
    {:noreply,
     socket
     |> push_event("setVolume", %{volume: volume})
     |> assign(:volume, String.to_integer(volume))}
  end

  def handle_event("mute_click", %{"value" => ""}, socket) do
    toggle_mute(socket)
  end

  def handle_event("mute_key", %{"key" => "m", "value" => ""}, socket) do
    toggle_mute(socket)
  end

  def handle_event("mute_key", _, socket) do
    {:noreply, socket}
  end

  defp play_video(socket) do
    {:noreply, push_event(socket, "playVideo", %{}) |> assign(:playing, true)}
  end

  defp pause_video(socket) do
    {:noreply, push_event(socket, "pauseVideo", %{}) |> assign(:playing, false)}
  end

  defp toggle_mute(socket) do
    {:noreply,
     socket
     |> push_event("toggleMute", %{})
     |> assign(:muted, !socket.assigns.muted)}
  end
end
