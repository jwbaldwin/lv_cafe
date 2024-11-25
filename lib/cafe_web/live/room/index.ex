defmodule CafeWeb.RoomLive do
  use CafeWeb, :live_view

  def mount(params, _session, socket) do
    socket = stream(socket, :presences, [])

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
    <ul id="online_users" phx-update="stream">
      <li :for={{dom_id, %{id: id, metas: metas}} <- @streams.presences} id={dom_id}>
        <%= id %> (<%= length(metas) %>)
      </li>
    </ul>
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
end
