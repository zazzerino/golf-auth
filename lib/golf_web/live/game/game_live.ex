defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  import GolfWeb.GameComponents

  alias Golf.Games
  alias Golf.Games.Event

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
         playable_cards: [],
         user_player: nil,
         can_start_game?: false
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
    game = Games.get_game(game_id, preloads: [players: :user])
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
         true <- card in playable_cards do
      case game.status do
        s when s in [:flip2, :flip] ->
          unless Map.has_key?(value, "face-up") do
            event = %Event{
              game_id: game.id,
              player_id: user_player.id,
              action: :flip,
              hand_index: index
            }

            {:ok, _} = Games.handle_game_event(game, user_player, event)
          end

        :hold ->
          event = %Event{
            game_id: game.id,
            player_id: user_player.id,
            action: :swap,
            hand_index: index
          }

          {:ok, _} = Games.handle_game_event(game, user_player, event)
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "deck_click",
        %{"playable" => _},
        %{assigns: %{user_player: player, game: game}} = socket
      )
      when is_struct(player) do
    event = %Event{game_id: game.id, player_id: player.id, action: :take_from_deck}
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
    event = %Event{game_id: game.id, player_id: player.id, action: :take_from_table}
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
    event = %Event{game_id: game.id, player_id: player.id, action: :discard}
    Games.handle_game_event(game, player, event)
    {:noreply, socket}
  end

  defp assign_game_data(%{assigns: %{current_user: user}} = socket, game)
       when is_struct(user) do
    user_is_playing? = Games.user_is_playing_game?(user.id, game.id)
    user_index = user_is_playing? && Enum.find_index(game.players, &(&1.user_id == user.id))
    user_player = user_index && Enum.at(game.players, user_index)
    can_start_game? = user_player && user_player.host? && game.status == :init
    playable_cards = Games.playable_cards(game, user_player)

    players =
      game.players
      |> assign_positions_and_scores()
      |> maybe_rotate(user_index, user_is_playing?)

    assign(socket,
      game: game,
      players: players,
      user_player: user_player,
      can_start_game?: can_start_game?,
      playable_cards: playable_cards
    )
  end

  defp assign_game_data(socket, game) do
    players =
      game.players
      |> assign_positions_and_scores()

    assign(socket,
      game: game,
      players: players
    )
  end

  defp assign_positions_and_scores(players) do
    positions = hand_positions(length(players))

    Enum.zip_with(players, positions, fn player, position ->
      player
      |> Map.put(:position, position)
      |> Map.put(:score, Games.score(player.hand))
    end)
  end

  defp maybe_rotate(players, user_index, user_is_playing?)
       when user_is_playing? do
    rotate(players, user_index)
  end

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
