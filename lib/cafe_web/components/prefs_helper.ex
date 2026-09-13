defmodule CafeWeb.PrefsHelper do
  @moduledoc "Validates the player's saved theme preferences without creating atoms from client input."

  alias Cafe.Stations
  @default %{theme: :vibes, sub_theme: :cozy}

  def init_preferences(socket) do
    if Phoenix.LiveView.connected?(socket) do
      params = Phoenix.LiveView.get_connect_params(socket) || %{}
      normalize(params["preferences"])
    end
  end

  def set_preference(socket, theme, sub_theme) do
    preferences = normalize(%{"theme" => theme, "sub_theme" => sub_theme})

    socket
    |> Phoenix.Component.assign(:preferences, preferences)
    |> Phoenix.LiveView.push_event("store_preferences", %{preferences: preferences})
  end

  defp normalize(%{"theme" => category, "sub_theme" => name}) do
    candidates =
      case category do
        "seasons" -> Enum.map(Stations.get_seasons(), &%{theme: :seasons, sub_theme: &1})
        "vibes" -> Enum.map(Stations.get_vibes(), &%{theme: :vibes, sub_theme: &1})
        _ -> []
      end

    Enum.find(candidates, @default, &(Atom.to_string(&1.sub_theme) == name))
  end

  defp normalize(_), do: @default
end
