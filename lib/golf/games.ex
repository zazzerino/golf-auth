defmodule Golf.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false

  alias Golf.Repo
  alias Golf.Accounts.User
  alias Golf.Games.{Game, Player, Event}

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @card_positions [:deck, :table, :held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

  @num_decks_to_use 2
  @max_players 4
  @hand_size 6

  def broadcast_game(game_id) when is_integer(game_id) do
    game = get_game(game_id, preloads: [players: :user])

    Phoenix.PubSub.broadcast(
      Golf.PubSub,
      "game:#{game_id}",
      {:game, game}
    )
  end

  # game logic

  def new_deck(1), do: @card_names
  def new_deck(n), do: @card_names ++ new_deck(n - 1)

  def new_deck(), do: new_deck(1)

  def deal_from_deck([], _) do
    {:error, :empty_deck}
  end

  def deal_from_deck(deck, n) when length(deck) < n do
    {:error, :not_enough_cards}
  end

  def deal_from_deck(deck, n) do
    {cards, deck} = Enum.split(deck, n)
    {:ok, cards, deck}
  end

  def deal_from_deck(deck) do
    with {:ok, [card], deck} <- deal_from_deck(deck, 1) do
      {:ok, card, deck}
    end
  end

  def current_player_turn(%Game{} = game) do
    num_players = length(game.players)
    rem(game.turn, num_players)
  end

  defguard is_players_turn(game, player) when rem(game.turn, length(game.players)) == player.turn

  def flip_card(hand, index) do
    List.update_at(hand, index, fn card -> Map.put(card, "face_up?", true) end)
  end

  def swap_card(hand, card_name, index) do
    old_card = Enum.at(hand, index) |> Map.get("name")
    hand = List.replace_at(hand, index, %{"name" => card_name, "face_up?" => true})
    {old_card, hand}
  end

  defp num_cards_face_up(hand) do
    Enum.count(hand, fn card -> card["face_up?"] end)
  end

  defp one_face_down?(hand) do
    num_cards_face_up(hand) == @hand_size - 1
  end

  defp all_face_up?(hand) do
    num_cards_face_up(hand) == @hand_size
  end

  defp all_have_two_face_up?(players) do
    Enum.all?(players, fn p -> num_cards_face_up(p.hand) >= 2 end)
  end

  defp all_players_all_flipped?(players) do
    Enum.all?(players, fn p -> all_face_up?(p.hand) end)
  end

  def face_down_cards(hand) do
    hand
    |> Enum.with_index()
    |> Enum.reject(fn {card, _} -> card["face_up?"] end)
    |> Enum.map(fn {_, index} -> String.to_existing_atom("hand_#{index}") end)
  end

  def playable_cards(%Game{status: :flip2}, %Player{} = player) do
    if num_cards_face_up(player.hand) < 2 do
      face_down_cards(player.hand)
    else
      []
    end
  end

  def playable_cards(%Game{} = game, %Player{} = player)
      when is_players_turn(game, player) do
    case game.status do
      s when s in [:flip2, :flip] ->
        face_down_cards(player.hand)

      :take ->
        [:deck, :table]

      :hold ->
        [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

      _ ->
        []
    end
  end

  def playable_cards(%Game{}, %Player{}) do
    []
  end

  # game queries

  def get_game(game_id, opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])

    Repo.get(Game, game_id)
    |> Repo.preload(preloads)
  end

  def get_player_by_user_id(game_id, user_id) do
    from(p in Player, where: p.game_id == ^game_id and p.user_id == ^user_id)
    |> Repo.one()
  end

  def game_exists?(game_id) when is_integer(game_id) do
    from(g in Game, where: g.id == ^game_id)
    |> Repo.exists?()
  end

  def user_is_playing_game?(user_id, game_id) do
    from(p in Player, where: p.user_id == ^user_id and p.game_id == ^game_id)
    |> Repo.exists?()
  end

  # game db updates

  def create_game(%User{} = user) do
    deck = new_deck(@num_decks_to_use) |> Enum.shuffle()

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:game, %Game{status: :init, deck: deck, table_cards: [], turn: 0})
    |> Ecto.Multi.insert(:player, fn %{game: game} ->
      Ecto.build_assoc(game, :players, %{user_id: user.id, turn: 0, host?: true})
    end)
    |> Repo.transaction()
  end

  def start_game(%Game{status: :init} = game) do
    num_cards_to_deal = @hand_size * length(game.players)
    {card_names, deck} = Enum.split(game.deck, num_cards_to_deal)

    {:ok, card, deck} = deal_from_deck(deck)
    table_cards = [card | game.table_cards]

    hands =
      Enum.map(card_names, fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(@hand_size)

    player_changesets =
      game.players
      |> Enum.zip(hands)
      |> Enum.map(fn {player, hand} -> Player.changeset(player, %{hand: hand}) end)

    {:ok, %{game: game} = multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:game, Game.changeset(game, %{status: :flip2, deck: deck, table_cards: table_cards}))
      |> update_players(player_changesets)
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  defp update_players(multi, player_changesets) do
    Enum.reduce(player_changesets, multi, fn player_cs, multi ->
      Ecto.Multi.update(multi, {:player, player_cs.data.id}, player_cs)
    end)
  end

  defp replace_player(players, player) do
    Enum.map(
      players,
      fn p -> if p.id == player.id, do: player, else: p end
    )
  end

  def handle_game_event(
        %Game{status: :flip2} = game,
        %Player{} = player,
        %Event{action: :flip} = event
      ) do
    if num_cards_face_up(player.hand) < 2 do
      hand = flip_card(player.hand, event.hand_index)

      {:ok, multi} =
        Ecto.Multi.new()
        |> Ecto.Multi.insert(:event, event)
        |> Ecto.Multi.update(:player, Player.changeset(player, %{hand: hand}))
        |> Ecto.Multi.update(:game, fn %{player: player} ->
          players = replace_player(game.players, player)
          status = if all_have_two_face_up?(players), do: :take, else: :flip2
          Game.changeset(game, %{status: status})
        end)
        |> Repo.transaction()

      broadcast_game(game.id)
      {:ok, multi}
    else
      {:error, :already_flipped_two}
    end
  end

  def handle_game_event(
        %Game{status: :flip} = game,
        %Player{} = player,
        %Event{action: :flip} = event
      ) do
    hand = flip_card(player.hand, event.hand_index)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{hand: hand}))
      |> Ecto.Multi.update(:game, fn %{player: player} ->
        players = replace_player(game.players, player)

        {status, turn} =
          cond do
            all_players_all_flipped?(players) ->
              {:over, game.turn}

            all_face_up?(player.hand) ->
              {:last_take, game.turn + 1}

            true ->
              {:take, game.turn + 1}
          end

        Game.changeset(game, %{status: status, turn: turn})
      end)
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :take} = game,
        %Player{} = player,
        %Event{action: :take_from_deck} = event
      ) do
    {:ok, card, deck} = deal_from_deck(game.deck)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(:game, Game.changeset(game, %{status: :hold, deck: deck}))
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :take} = game,
        %Player{} = player,
        %Event{action: :take_from_table} = event
      ) do
    [card | table_cards] = game.table_cards

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: :hold, table_cards: table_cards})
      )
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :hold} = game,
        %Player{} = player,
        %Event{action: :discard} = event
      )
      when is_struct(player) do
    card = player.held_card
    table_cards = [card | game.table_cards]

    {status, turn} =
      if one_face_down?(player.hand) do
        {:take, game.turn + 1}
      else
        {:flip, game.turn}
      end

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: nil}))
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: status, table_cards: table_cards, turn: turn})
      )
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  def handle_game_event(
        %Game{status: :hold} = game,
        %Player{} = player,
        %Event{action: :swap} = event
      )
      when is_struct(player) do
    {card, hand} = swap_card(player.hand, player.held_card, event.hand_index)
    table_cards = [card | game.table_cards]

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{hand: hand, held_card: nil}))
      |> Ecto.Multi.update(:game, fn %{player: player} ->
        players = replace_player(game.players, player)

        {status, turn} =
          cond do
            all_players_all_flipped?(players) ->
              {:over, game.turn}

            all_face_up?(player.hand) ->
              {:last_take, game.turn + 1}

            true ->
              {:take, game.turn + 1}
          end

        Game.changeset(game, %{status: status, table_cards: table_cards, turn: turn})
      end)
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  # @doc """
  # Returns the list of games.

  # ## Examples

  #     iex> list_games()
  #     [%Game{}, ...]

  # """
  # def list_games do
  #   Repo.all(Game)
  # end

  # @doc """
  # Gets a single game.

  # Raises `Ecto.NoResultsError` if the Game does not exist.

  # ## Examples

  #     iex> get_game!(123)
  #     %Game{}

  #     iex> get_game!(456)
  #     ** (Ecto.NoResultsError)

  # """
  # def get_game!(id), do: Repo.get!(Game, id)

  # @doc """
  # Creates a game.

  # ## Examples

  #     iex> create_game(%{field: value})
  #     {:ok, %Game{}}

  #     iex> create_game(%{field: bad_value})
  #     {:error, %Ecto.Changeset{}}

  # """
  # def create_game(attrs \\ %{}) do
  #   %Game{}
  #   |> Game.changeset(attrs)
  #   |> Repo.insert()
  # end

  # @doc """
  # Updates a game.

  # ## Examples

  #     iex> update_game(game, %{field: new_value})
  #     {:ok, %Game{}}

  #     iex> update_game(game, %{field: bad_value})
  #     {:error, %Ecto.Changeset{}}

  # """
  # def update_game(%Game{} = game, attrs) do
  #   game
  #   |> Game.changeset(attrs)
  #   |> Repo.update()
  # end

  # @doc """
  # Deletes a game.

  # ## Examples

  #     iex> delete_game(game)
  #     {:ok, %Game{}}

  #     iex> delete_game(game)
  #     {:error, %Ecto.Changeset{}}

  # """
  # def delete_game(%Game{} = game) do
  #   Repo.delete(game)
  # end

  # @doc """
  # Returns an `%Ecto.Changeset{}` for tracking game changes.

  # ## Examples

  #     iex> change_game(game)
  #     %Ecto.Changeset{data: %Game{}}

  # """
  # def change_game(%Game{} = game, attrs \\ %{}) do
  #   Game.changeset(game, attrs)
  # end
end
