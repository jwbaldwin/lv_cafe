defmodule CafeWeb.RoomStats do
  use CafeWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="absolute top-0 left-0 flex w-full py-8 px-12 z-[2]">
      <div class="text-white text-shadow-red w-full z-[2]">
        <span class="inline-block w-1.5 h-1.5 ml-1.5 bg-red-400 animate-[blink_2s_steps(2,_start)_infinite] opacity-0">
        </span>
        {@presences} {if @presences == 1, do: "person", else: "people"} vibing
      </div>
    </div>
    """
  end
end
