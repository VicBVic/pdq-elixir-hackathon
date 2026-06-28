defmodule SchoolWeb.MainLive do
  use SchoolWeb, :live_view

  alias School.Logic
  alias School.State

  import SchoolWeb.GameComponents

  @impl true
  def mount(_params, _session, socket) do
    package = Logic.generate_package()

    Phoenix.PubSub.subscribe(School.PubSub, "game_room")
    Phoenix.PubSub.subscribe(School.PubSub, "sabotage")

    active_players = State.get_active_players()
    game_state = State.get_game_state()
    active_rules = State.get_active_rules(self())
    rule_descriptions = Logic.rule_description_set(active_rules)

    new_socket =
      socket
      |> assign(:local_player, nil)
      |> assign(:package, package)
      |> assign(:timestamp, 0)
      |> assign(:total_correct, 0)
      |> assign(:is_correct, true)
      |> assign(:game_state, game_state)
      |> assign(:active_rules, active_rules)
      |> assign(:rule_descriptions, rule_descriptions)
      |> assign(:score, 0)
      |> assign(:max_time, State.max_game_time())
      |> assign(:waiting_for_other_players, false)
      |> assign(:player_list, active_players)

    {:ok, new_socket}
  end


  @impl true
  def handle_event("join", %{"name" => name}, socket) do
    local_player = State.add_player(name, self())

    new_socket =
      socket
      |> assign(:local_player, local_player)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("ready", _params, socket) do
    local_player = socket.assigns.local_player
    {updated_local_player, state_tag} = State.player_ready(local_player.pid)

    new_socket =
      socket
      |> assign(:local_player, updated_local_player)
      |> assign(:waiting_for_other_players, state_tag == :initial)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("selected", %{"index" => index}, socket) do
    {index, _} = Integer.parse(index)

    rule =
      socket.assigns.rules_for_selection
      |> Enum.at(index)

    local_player = socket.assigns.local_player
    {player, state_tag} = State.rule_selected(rule, local_player.pid)

    new_socket =
      socket
      |> assign(:local_player, player)
      |> assign(:waiting_for_other_players, state_tag == :selecting)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("decline", _params, socket) do
    new_socket = validation("swipe-left", :invalid, socket)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("approve", _params, socket) do
    new_socket = validation("swipe-right", :valid, socket)

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("new-match", _params, socket) do
    new_socket =
      socket
      |> assign(:game_state, State.get_game_state())

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    new_socket =
      socket
      |> assign(:rules_for_selection, Logic.random_rules())

    {:noreply, new_socket}
  end

  @impl true
  def handle_event("sabotage-completed", %{"index" => index}, socket) do
    :TODO
    new_socket =
      socket
      |> assign(:game_state, :running)
    Process.send(self(), :next_package, [])
    State.sabotage_selected(self(), index)
    {:noreply, new_socket}
  end

  @impl true
  def handle_info(:next_package, socket) do
    package = Logic.generate_package()

    new_socket =
      socket
      |> assign(:package, package)
      |> push_event("reset-package-card", %{})

    {:noreply, new_socket}
  end

  @impl true
  def handle_info(:sabotage_round, socket) do
    new_socket =
      socket
      |> assign(:game_state, :sabotage)
    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:game_start, game_state}, socket) do
    IO.inspect("BBBB #{game_state}")

    new_socket =
      socket
      |> assign(:game_state, game_state)
      |> assign(:rules_for_selection, Logic.random_rules())
      |> assign(:waiting_for_other_players, false)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:all_players_selected, game_state}, socket) do
    IO.inspect("CCCCC #{game_state}")

    new_socket =
      socket
      |> assign(:game_state, game_state)
      |> assign(:waiting_for_other_players, false)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:game_ended, full_state}, socket) do

    active_rules = State.get_active_rules(self())
    active_players = State.get_active_players()
    rule_descriptions = Logic.rule_description_set(active_rules)

    updated_local_player = Map.get(full_state.players, self())

    new_socket =
      socket
      |> assign(:local_player, updated_local_player)
      |> assign(:timestamp, 0)
      |> assign(:is_correct, true)
      |> assign(:active_rules, active_rules)
      |> assign(:rule_descriptions, rule_descriptions)
      |> assign(:score, 0)
      |> assign(:total_correct, 0)
      |> assign(:waiting_for_other_players, false)
      |> assign(:player_list, active_players)
      |> assign(:game_state, :ended)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:time_updated, current_game_time}, socket) do
    width = build_game_time_loading_bar(State.max_game_time() - current_game_time)

    new_socket =
      socket
      |> push_event("timer-tick", %{time: State.max_game_time() - current_game_time, width: width})

    {:noreply, new_socket}
  end

  @impl true
  def handle_info(:update_rules, socket) do
    active_rules = State.get_active_rules(self())
    rule_descriptions = Logic.rule_description_set(active_rules)

    new_socket =
      socket
      |> assign(:rule_descriptions, rule_descriptions)
      |> assign(:active_rules, active_rules)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:update_player_list, updated_player_list}, socket) do
    new_socket =
      socket
      |> assign(:player_list, updated_player_list)
      |> assign(:game_state, State.get_game_state())
    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:sabotage_new_rule, pid}, socket) do
    if pid == self() do
      {:noreply, socket}
    else
      State.sabotage_new_rule(self())
      {:noreply, socket}
    end
  end

  defp validation(swipe_direction, expected, socket) do
    package = socket.assigns.package

    {updated_player, is_correct} =
      State.update_player_score(self(), package, expected)

    total_correct = socket.assigns.total_correct + (if is_correct, do: 1, else: 0)

    new_socket =
      socket
      |> assign(:is_correct, is_correct)
      |> assign(:validation_msg, "TODO")
      |> assign(:total_correct, total_correct)
      |> assign(:local_player, updated_player)
      |> assign(:score, updated_player.score)
      |> push_event(swipe_direction, %{})

    if total_correct == 2 do
      new_socket =
        new_socket
        |> assign(:total_correct, 0)
      Process.send_after(self(), :sabotage_round, 1_000)
      new_socket
    else
      Process.send_after(self(), :next_package, 1_000)
      new_socket
    end
  end

  def build_game_time_loading_bar(game_time) do
    max_game_time = State.max_game_time()
    game_time / max_game_time * 100
  end
end
