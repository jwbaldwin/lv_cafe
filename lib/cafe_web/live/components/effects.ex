defmodule CafeWeb.Effects do
  use CafeWeb, :html

  attr :effect, :atom, default: :winter

  def effect(%{effect: :winter} = assigns) do
    ~H"""
    <div class="snow-effect">
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

  def effect(%{effect: :autumn} = assigns) do
    ~H"""
    <div class="autumn-effect"></div>
    """
  end

  def effect(%{effect: :summer} = assigns) do
    ~H"""
    <div class="summer-effect"></div>
    """
  end

  def effect(%{effect: :spring} = assigns) do
    ~H"""
    <div class="spring-effect"></div>
    """
  end

  def effect(assigns) do
    ~H"""
    <div />
    """
  end
end
