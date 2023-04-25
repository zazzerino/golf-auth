defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  import GolfWeb.GameComponents

  alias Golf.Games
  alias Golf.Games.Event
  alias Golf.ChatMessage

  @max_players Games.max_players()

  @impl true
  def mount(%{"game_id" => game_id}, _, socket) do
    with {game_id, _} <- Integer.parse(game_id),
         true <- Games.game_exists?(game_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Golf.PubSub, "game:#{game_id}")
        send(self(), {:get_game, game_id})
      end

      {:ok,
       assign(socket,
         page_title: "Game #{game_id}",
         game_id: game_id,
         game: nil,
         players: [],
         event: nil,
         chat_messages: [],
         playable_cards: [],
         user_player: nil,
         draw_table_cards_last?: nil,
         can_start_game?: nil,
         can_join_game?: nil,
        #  chat_message: %ChatMessage{}
         chat_form: to_form(ChatMessage.content_changeset(%ChatMessage{}, %{}))
       )}
    else
      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Game #{game_id} not found.")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_info({:get_game, game_id}, socket) do
    game = Games.get_game_players_event_and_messages(game_id)
    {:noreply, assign_game_data(socket, game)}
  end

  @impl true
  def handle_info({:game, game}, socket) do
    {:noreply, assign_game_data(socket, game)}
  end

  @impl true
  def handle_event("start_game", _, %{assigns: %{user_player: player, game: game}} = socket)
      when is_struct(player) and player.host? do
    {:ok, _} = Games.start_game(game)
    {:noreply, socket}
  end

  @impl true
  def handle_event("join_game", _, %{assigns: %{current_user: user, game: game}} = socket)
      when is_struct(user) and length(game.players) < @max_players do
    {:ok, _} = Games.add_player_to_game(game, user)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "hand_click",
        value,
        %{assigns: %{user_player: user_player, game: game, playable_cards: playable_cards}} =
          socket
      )
      when is_struct(user_player) do
    with player_id <- String.to_integer(value["player-id"]),
         index <- String.to_integer(value["index"]),
         card <- String.to_existing_atom("hand_#{index}"),
         true <- player_id == user_player.id,
         true <- card in playable_cards,
         event <- held_click_event(game, user_player, index),
         {:ok, _} <- Games.handle_game_event(game, user_player, event) do
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "deck_click",
        %{"playable" => _},
        %{assigns: %{user_player: player, game: game}} = socket
      )
      when is_struct(player) do
    event = Event.take_from_deck(game.id, player.id)
    Games.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "table_click",
        %{"playable" => _},
        %{assigns: %{user_player: player, game: game}} = socket
      )
      when is_struct(player) do
    event = Event.take_from_table(game.id, player.id)
    Games.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "held_click",
        %{"playable" => _},
        %{assigns: %{user_player: player, game: game}} = socket
      )
      when is_struct(player) do
    event = Event.discard(game.id, player.id)
    Games.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_chat_message", %{"chat_message" => params}, socket) do
    form =
      %ChatMessage{}
      |> ChatMessage.content_changeset(params)
      |> Map.put(:action, :insert)
      |> to_form()

    {:noreply, assign(socket, chat_form: form)}
  end

  @impl true
  def handle_event(
        "send_chat_message",
        %{"chat_message" => %{"content" => content}},
        %{assigns: %{game_id: game_id, current_user: user}} = socket
      )
      when is_struct(user) do
    changeset =
      %ChatMessage{}
      |> ChatMessage.changeset(%{game_id: game_id, user_id: user.id, content: content})

    if changeset.valid? do
      {:ok, message} = Ecto.Changeset.apply_action(changeset, :insert)
      {:ok, _} = Games.insert_chat_message(message)
    end

    chat_form =
      %ChatMessage{}
      |> ChatMessage.content_changeset(%{})
      |> to_form()

    {:noreply, assign(socket, chat_form: chat_form)}
  end

  defp assign_game_data(%{assigns: %{current_user: user}} = socket, game)
       when is_struct(user) do
    user_is_playing? = Games.user_is_playing_game?(user.id, game.id)
    user_index = user_is_playing? && Enum.find_index(game.players, &(&1.user_id == user.id))
    user_player = user_index && Enum.at(game.players, user_index)

    can_start_game? = user_player && user_player.host? && game.status == :init
    can_join_game? = not user_is_playing? and game.status == :init

    playable_cards =
      if user_is_playing? do
        Games.playable_cards(game, user_player)
      else
        []
      end

    positions = hand_positions(length(game.players))

    players =
      game.players
      |> maybe_rotate(user_index, user_is_playing?)
      |> assign_positions_and_scores(positions)

    event = get_recent_event(game.events, players)
    draw_table_cards_last? = event && event.action not in [:take_from_deck, :take_from_table]

    assign(socket,
      game: game,
      players: players,
      event: event,
      chat_messages: game.chat_messages,
      user_player: user_player,
      playable_cards: playable_cards,
      draw_table_cards_last?: draw_table_cards_last?,
      can_start_game?: can_start_game?,
      can_join_game?: can_join_game?
    )
  end

  defp assign_game_data(socket, game) do
    positions = hand_positions(length(game.players))

    players =
      game.players
      |> assign_positions_and_scores(positions)

    event = get_recent_event(game.events, players)
    draw_table_cards_last? = event && event.action not in [:take_from_deck, :take_from_table]

    assign(socket,
      game: game,
      players: players,
      event: event,
      chat_messages: game.chat_messages,
      draw_table_cards_last?: draw_table_cards_last?
    )
  end

  defp assign_positions_and_scores(players, positions) do
    Enum.zip_with(players, positions, fn player, position ->
      player
      |> Map.put(:position, position)
      |> Map.put(:score, Games.score(player.hand))
    end)
  end

  defp get_recent_event(events, players) do
    events
    |> List.first()
    |> maybe_put_position(players)
  end

  defp maybe_put_position(event, _) when is_nil(event), do: nil

  defp maybe_put_position(event, players) do
    player = Enum.find(players, fn p -> p.id == event.player_id end)
    Map.put(event, :position, player.position)
  end

  defp held_click_event(game, player, hand_index) do
    case game.status do
      s when s in [:flip2, :flip] ->
        Event.flip(game.id, player.id, hand_index)

      :hold ->
        Event.swap(game.id, player.id, hand_index)
    end
  end

  defp maybe_rotate(players, index, true), do: rotate(players, index)
  defp maybe_rotate(players, _, _), do: players

  defp rotate(list, 0), do: list

  defp rotate(list, n) when is_integer(n) do
    list
    |> Stream.cycle()
    |> Stream.drop(n)
    |> Stream.take(length(list))
    |> Enum.to_list()
  end
end
