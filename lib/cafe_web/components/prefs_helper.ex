defmodule CafeWeb.PrefsHelper do
  @moduledoc """
  Provides helper functions for working with the JS hook preferences.
  """

  def init_preferences(socket) do
    if Phoenix.LiveView.connected?(socket) do
      Phoenix.LiveView.get_connect_params(socket)["preferences"]
      |> string_to_atom_map()
    else
      nil
    end
  end

  def set_preference(socket, theme, sub_theme) do
    new_preferences =
      Map.merge(socket.assigns.preferences, %{
        theme: String.to_existing_atom(theme),
        sub_theme: String.to_existing_atom(sub_theme)
      })

    # There is an issue here where updating the preferences causes the liveview to re-render
    socket = Phoenix.Component.assign(socket, preferences: new_preferences)

    Phoenix.LiveView.push_event(socket, "store_preferences", %{
      preferences: new_preferences
    })
  end

  defp string_to_atom_map(map) do
    Map.new(map, fn {k, v} ->
      {String.to_atom(k), String.to_atom(v)}
    end)
  end
end
