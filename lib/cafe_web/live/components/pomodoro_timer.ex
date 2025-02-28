defmodule CafeWeb.PomodoroTimer do
  use CafeWeb, :live_component

  # Define timer durations in seconds
  @default_work_duration 60 * 25
  @default_break_duration 60 * 5

  def mount(socket) do
    {:ok,
     socket
     |> assign(:open, false)
     |> assign(:timer_state, :stopped)
     |> assign(:current_timer, :work)
     |> assign(:time_left, @default_work_duration)
     |> assign(:work_duration, @default_work_duration)
     |> assign(:break_duration, @default_break_duration)}
  end

  def handle_event("toggle_timer", _params, socket) do
    {:noreply, assign(socket, :open, !socket.assigns.open)}
  end

  def handle_event("start_timer", _params, socket) do
    send_update_after(self(), __MODULE__, %{id: "pomodoro-timer", update: :tick}, 1000)
    {:noreply, assign(socket, :timer_state, :running)}
  end

  def handle_event("pause_timer", _params, socket) do
    {:noreply, assign(socket, :timer_state, :paused)}
  end

  def handle_event("reset_timer", _params, socket) do
    time_left =
      case socket.assigns.current_timer do
        :work -> socket.assigns.work_duration
        :break -> socket.assigns.break_duration
      end

    {:noreply, socket |> assign(:timer_state, :stopped) |> assign(:time_left, time_left)}
  end

  def handle_event("control_keypress", %{"key" => key}, socket) do
    case key do
      "p" -> {:noreply, assign(socket, :open, !socket.assigns.open)}
      _ -> {:noreply, socket}
    end
  end

  def update(assigns, socket) do
    IO.inspect(assigns, label: "assigns")
    assigns = socket.assigns

    if socket.assigns.timer_state == :running do
      new_time_left = socket.assigns.time_left - 1

      socket =
        if new_time_left <= 0 do
          # Timer finished - switch between work and break
          {new_timer, new_time_left} =
            case socket.assigns.current_timer do
              :work -> {:break, socket.assigns.break_duration}
              :break -> {:work, socket.assigns.work_duration}
            end

          # Play a sound effect here if desired
          # send(self(), {:play_timer_sound})

          socket
          |> assign(:current_timer, new_timer)
          |> assign(:time_left, new_time_left)
        else
          socket |> assign(:time_left, new_time_left)
        end

      # Schedule next tick
      if assigns.timer_state == :running do
        send_update_after(self(), __MODULE__, %{id: "pomodoro-timer", update: :tick}, 1000)
      end

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  def update(_assigns, socket), do: {:ok, socket}

  defp format_time(seconds) do
    minutes = div(seconds, 60)
    seconds = rem(seconds, 60)
    :io_lib.format("~2..0B:~2..0B", [minutes, seconds]) |> IO.iodata_to_binary()
  end

  def render(assigns) do
    ~H"""
    <div id="pomodoro" class="absolute bottom-8 right-12 z-[90]">
      <button
        phx-click="toggle_timer"
        phx-window-keyup="control_keypress"
        phx-key="p"
        phx-target={@myself}
        class="p-2 text-white svg-shadow-red z-[90]"
      >
        <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
          <path
            d="M12 8v4l3 3m6-3c0 5.523-4.477 10-10 10S2 17.523 2 12 6.477 2 12 2s10 4.477 10 10z"
            stroke="currentColor"
            stroke-width="1.5"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </button>
      <div
        :if={@open}
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
        class="fixed right-0 bottom-24"
      >
        <pre class="text-gray-300 font-mono text-shadow-green text-sm whitespace-pre-wrap w-52">
        +----------------+
        |   [Pomodoro]   |
        |                |
        |  work:   <%= if @current_timer == :work, do: format_time(@time_left), else: format_time(@work_duration)  %> |
        | break:   <%= if @current_timer == :break, do: format_time(@time_left), else: format_time(@break_duration)  %> |
        |                |
        | <%= if @timer_state == :running do %><button phx-click="pause_timer" phx-target={@myself} class="text-white text-shadow-white hover:text-white">[paus]</button><% else %><button phx-click="start_timer" phx-target={@myself} class="text-white text-shadow-white hover:text-white">[play]</button><% end %>   <button phx-click="reset_timer" phx-target={@myself} class="text-white text-shadow-red hover:text-white">[rst]</button> |
        +----------------+
        </pre>
      </div>
    </div>
    """
  end
end
