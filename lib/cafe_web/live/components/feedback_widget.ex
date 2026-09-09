defmodule CafeWeb.FeedbackWidget do
  use CafeWeb, :live_component

  def mount(socket), do: {:ok, assign(socket, open: false, sent: false, error: nil, message: "")}

  def update(assigns, socket) do
    socket =
      if Map.has_key?(socket.assigns, :initial_open),
        do: socket,
        else: assign(socket, :initial_open, assigns[:initial_open] || false)

    {:ok, assign(socket, Map.delete(assigns, :initial_open))}
  end

  def handle_event("toggle", _, socket) do
    {:noreply,
     assign(socket,
       open: !(socket.assigns.open || socket.assigns.initial_open),
       initial_open: false,
       sent: false,
       error: nil
     )}
  end

  def handle_event("submit", %{"feedback" => attrs}, socket) do
    admin = CafeWeb.AdminAuth.valid?(socket.assigns.admin_token)
    message = Map.get(attrs, "message", "")

    cond do
      !admin && !Cafe.RateLimit.allow?({:feedback, socket.assigns.session_id}, 10, 3600) ->
        {:noreply, assign(socket, error: "Please try again later.", message: message)}

      true ->
        # Context comes from the current server-side station, never submitted fields.
        context = %{
          video_id: socket.assigns.station.video_id,
          playlist_name: socket.assigns.station.name
        }

        case Cafe.Curation.submit_player_feedback(
               message,
               context,
               if(admin, do: "admin", else: "visitor")
             ) do
          {:ok, _} ->
            {:noreply, assign(socket, sent: true, message: "", error: nil)}

          {:error, _} ->
            {:noreply, assign(socket, error: "Enter 1–255 characters.", message: message)}
        end
    end
  end

  def render(assigns) do
    ~H"""
    <div id={@id} class="feedback-widget" phx-hook="FeedbackWidget">
      <button
        id="feedback-toggle"
        type="button"
        phx-click="toggle"
        phx-target={@myself}
        aria-label="Leave feedback"
        aria-expanded={@open || @initial_open}
        aria-controls="feedback-panel"
        class="p-2 text-white svg-shadow-red"
      >
        <svg
          class="w-5 h-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          aria-hidden="true"
        >
          <path d="M5 4h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H9l-6 4V6a2 2 0 0 1 2-2Z" />
          <path d="M7 9h10M7 13h6" />
        </svg>
      </button>
      <section
        :if={@open || @initial_open}
        id="feedback-panel"
        class="feedback-panel ascii-surface"
        phx-mounted={CafeWeb.AsciiFrame.enter()}
        phx-remove={CafeWeb.AsciiFrame.exit()}
        aria-label="Feedback"
      >
        <CafeWeb.AsciiFrame.border />
        <header>
          <span>[Feedback]</span><button
            type="button"
            data-feedback-close
            phx-click="toggle"
            phx-target={@myself}
            aria-label="Close feedback"
          >[x]</button>
        </header>
        <p :if={@sent} role="status">Thanks — sent to the inbox.</p>
        <form :if={!@sent} id="feedback-form" phx-submit="submit" phx-target={@myself}>
          <label class="sr-only" for="feedback-message">Your feedback</label>
          <textarea
            id="feedback-message"
            name="feedback[message]"
            rows="4"
            maxlength="255"
            required
            placeholder="What’s on your mind?"
            aria-describedby="feedback-count"
          >{@message}</textarea>
          <p :if={@error} role="alert">{@error}</p>
          <footer>
            <output id="feedback-count" for="feedback-message">0/255</output><button
              type="submit"
              phx-disable-with="[sending…]"
            >[send]</button>
          </footer>
        </form>
      </section>
    </div>
    """
  end
end
