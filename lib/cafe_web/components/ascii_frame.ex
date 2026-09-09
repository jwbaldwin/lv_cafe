defmodule CafeWeb.AsciiFrame do
  use CafeWeb, :html

  def enter do
    Phoenix.LiveView.JS.transition(
      {"ease-out duration-100", "opacity-0 translate-x-full", "opacity-100 translate-x-0"},
      time: 100
    )
  end

  def exit do
    Phoenix.LiveView.JS.transition(
      {"ease-in duration-100", "opacity-100 translate-x-0", "opacity-0 translate-x-full"},
      time: 100
    )
  end

  def border(assigns) do
    ~H"""
    <span class="ascii-frame" aria-hidden="true">
      <span :for={edge <- ~w(top bottom)} class={"ascii-edge ascii-" <> edge}>
        <span>+</span><span class="ascii-dashes">{String.duplicate("-", 80)}</span><span>+</span>
      </span>
      <span class="ascii-side ascii-left">{String.duplicate("|\n", 40)}</span>
      <span class="ascii-side ascii-right">{String.duplicate("|\n", 40)}</span>
    </span>
    """
  end
end
