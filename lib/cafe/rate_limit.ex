defmodule Cafe.RateLimit do
  @moduledoc "Small per-instance limits for sign-in attempts and public submissions."
  use GenServer

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, %{}, Keyword.put(opts, :name, __MODULE__))

  def allow?(key, limit, seconds), do: GenServer.call(__MODULE__, {:allow, key, limit, seconds})
  def init(state), do: {:ok, state}

  def handle_call({:allow, key, limit, seconds}, _from, state) do
    now = System.monotonic_time(:second)
    state = Map.reject(state, fn {_key, {_count, until}} -> until <= now end)
    {count, until} = Map.get(state, key, {0, now + seconds})
    allowed = count < limit && (map_size(state) < 10_000 || Map.has_key?(state, key))
    state = if allowed, do: Map.put(state, key, {count + 1, until}), else: state
    {:reply, allowed, state}
  end
end
