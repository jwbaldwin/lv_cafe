defmodule CafeWeb.Effects do
  use CafeWeb, :html

  attr :effect, :atom, default: :winter

  def effect(%{effect: :winter} = assigns) do
    ~H"""
    <div class="main-snow">
      <div class="initial-snow">
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
        <div class="snow">&#10052;</div>
      </div>
    </div>
    """
  end

  def effect(assigns) do
    ~H"""
    <div />
    """
  end
end
