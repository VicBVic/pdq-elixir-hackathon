defmodule School.State do
  use GenServer

  # game states:
  # :initial_state
  # :select_screen
  # :before_ready
  # :running  <---- (make players unable to join here!!)
  # :finished

  @max_time 30
  @type t :: %School.State{
          tag: :initial | :selecting | :running | :finished,
          players: %{pid() => School.Player.t()},
        }

  defstruct tag: :initial,
            players: %{},
            ready: 0,
            selected: 0,
            time: 0

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    Phoenix.PubSub.subscribe(School.PubSub, "clock")
    {:ok, %School.State{}}
  end

  @impl true
  def handle_call({:add_player, name, pid}, _, state) do
    player = %School.Player{name: name, pid: pid}
    new_players = Map.put(state.players, pid, player)
    Process.monitor(pid)
    IO.inspect("MONITORED")
    state = %{state | players: new_players}
    Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:update_player_list, Map.values(new_players)})
    {:reply, player, state}
  end

  @impl true
  def handle_call({:rule_selected, rule, pid}, _from, state) do
    player = Map.get(state.players, pid)
    if state.tag != :selecting do
      {:reply, {player, state.tag}, state}
    else

      if player == nil || player.selected? == true do
        {:reply, {player, state.tag}, state}
      else
        player = %{player | selected?: true}

        total_selected = state.selected + 1
        new_players = Map.put(state.players, pid, player)
        next_tag = if total_selected == map_size(state.players), do: :running, else: :selecting

        new_players = Map.new(new_players, fn {pid, player} -> 
          {pid, %{player | rules: [rule | player.rules]}} 
        end)

        state = %{
          state
          | players: new_players,
            tag: next_tag,
            selected: total_selected
        }

        Phoenix.PubSub.broadcast(School.PubSub, "game_room", :update_rules)
        if next_tag == :running, do: Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:all_players_selected, :running})


        {:reply, {player, next_tag}, state}
      end
    end
  end

  @impl true
  def handle_call({:update_score, pid, decision, package}, _from, state) do
    player = Map.get(state.players, pid)

    if state.tag != :running do
      {:reply, {player, nil}, state}
    else

      if player == nil do
        {:reply, {player, nil}, state}
      else
        correct_decision =
          if School.Logic.validate_set(state.players[pid].rules, package), do: :valid, else: :invalid

        was_correct = correct_decision == decision
        delta = if was_correct, do: 1, else: -1

        player = %{player | score: player.score + delta}
        new_players = Map.put(state.players, pid, player)
        Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:update_player_list, Map.values(new_players)})
        {:reply, {player, was_correct}, %{state | players: new_players}}
      end
    end
  end

  @impl true
  def handle_call({:player_ready, pid}, _from, state) do
    player = Map.get(state.players, pid)
    if state.tag != :initial do
      {:reply, {player, state.tag}, state}
    else

      if player == nil || player.ready? == true do
        {:reply, {player, state.tag}, state}
      else
        player = %{player | ready?: true}
        total_ready = state.ready + 1
        next_tag = if total_ready == map_size(state.players), do: :selecting, else: :initial
        new_players = Map.put(state.players, pid, player)
        state = %{state | players: new_players, tag: next_tag, ready: total_ready}

        if next_tag == :selecting, do: Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:game_start, :selecting})
        Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:update_player_list, Map.values(new_players)})

        {:reply, {player, next_tag}, state}
      end
    end
  end

  @impl true
  def handle_call({:get_rules, pid}, _from, state) do
    rules = if Map.get(state.players, pid) == nil do 
      [] 
    else 
      state.players[pid].rules end

     {:reply, rules, state}
  end

  @impl true
  def handle_call({:get_players}, _from, state) do
    {:reply, Map.values(state.players), state}
  end

  @impl true
  def handle_call({:get_game_state}, _from, state) do
    {:reply, state.tag, state}
  end

  @impl true
  def handle_info(:clock_tick, state) do
    if state.tag != :running do
      {:noreply, state}
    else
      time = state.time
      time = time + 1

      state = %{state | time: time}

      Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:time_updated, time})

      if time >= @max_time do
        state = end_game(state)
        {:noreply, state}
      else
        {:noreply, state}
      end
    end
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, state) do
    IO.inspect("AAA DEAD")
    player = Map.get(state.players, pid)
    if player == nil do
      {:reply, state.tag, state}
    end

    new_players = Map.delete(state.players, pid)
    Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:update_player_list, Map.values(new_players)})
    state = %{state | players: new_players}
    state = if map_size(new_players) == 0, do: end_game(state), else: state

    {:noreply, state}
  end

  def player_ready(pid) do
    GenServer.call(__MODULE__, {:player_ready, pid})
  end

  def add_player(name, pid) do
    GenServer.call(__MODULE__, {:add_player, name, pid})
  end

  def update_player_score(pid, package, decision) do
    GenServer.call(__MODULE__, {:update_score, pid, decision, package})
  end

  def get_active_rules(pid) do
    GenServer.call(__MODULE__, {:get_rules, pid})
  end

  def get_active_players() do
    GenServer.call(__MODULE__, {:get_players})
  end

  def get_game_state() do
    GenServer.call(__MODULE__, {:get_game_state})
  end

  def rule_selected(rule, pid) do
    GenServer.call(__MODULE__, {:rule_selected, rule, pid})
  end

  
  def sabotage_selected(pid, index) do
    GenServer.cast(__MODULE__, {:sabotage_selected, pid, index})
  end

  @impl true
  def handle_cast({:sabotage_selected, pid, index}, state) do
    case index do
      "1" -> true
      "2" -> true
      "3" -> true
      _ -> true
    end

    {:noreply, state}
  end


  def max_game_time do
    @max_time
  end

  def end_game(state) do
    players = state.players
    |> Enum.map(fn {key, value} -> {key, %{value | ready?: :false, selected?: :false, score: 0, rules: []}} end)
    |> Enum.into(%{})

    state = %{state | tag: :initial, time: 0, players: players, ready: 0,selected: 0}

    Phoenix.PubSub.broadcast(School.PubSub, "game_room", {:game_ended, state})

    state
  end
end
