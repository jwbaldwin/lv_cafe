defmodule CafeWeb.RoomStats do
  use CafeWeb, :live_component

  def mount(socket) do
    socket = assign(socket, :presences, 0)

    socket =
      if connected?(socket) do
        session_id = Ecto.UUID.generate()
        CafeWeb.Presence.track_user(session_id, %{id: session_id})
        CafeWeb.Presence.subscribe()
        IO.inspect(CafeWeb.Presence.list_online_users())
        assign(socket, :presences, length(CafeWeb.Presence.list_online_users()))
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="text-white width-full block relative z-[2]">{@presences} people vibing</div>
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
end
