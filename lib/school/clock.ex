defmodule School.Clock do
  use GenServer

  @tick_rate 1_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(School.PubSub, "game_room")
    {:ok, %{count: 0, active: :false}}
  end

  @impl true
  def handle_info(:tick, state) do
    if !state.active do
      {:noreply, state}
    else
      new_count = state.count + 1
      Process.send_after(self(), :tick, @tick_rate)

      Phoenix.PubSub.broadcast(School.PubSub, "clock", :clock_tick)

      {:noreply, %{state | count: new_count}}
    end
  end

  @impl true
  def handle_cast(:stop, state) do
    {:noreply, %{state | active: :false}}
  end

  @impl true
  def handle_cast(:start, state) do
    Process.send_after(self(), :tick, @tick_rate)
    {:noreply, %{state | active: :true}}
  end

  @impl true
  def handle_info({:all_players_selected, _}, state) do
    IO.inspect("wawa")
    Process.send_after(self(), :tick, @tick_rate)
    {:noreply, %{state | active: :true}}
  end

  @impl true
  def handle_info({:game_ended, _}, state) do
    {:noreply, %{state | active: :false}}
  end

  @impl true
  def handle_info(_, state) do
    {:noreply, state}
  end

  def start do
    GenServer.call(__MODULE__, :start)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end
end
