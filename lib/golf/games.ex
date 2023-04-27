defmodule Golf.Games do
  @moduledoc """
  The Games context.
  """

  import Ecto.Query, warn: false

  alias Golf.Repo
  alias Golf.Accounts.User
  alias Golf.Games.{Game, Player, Event}
  alias Golf.ChatMessage

  @card_names for rank <- ~w(A 2 3 4 5 6 7 8 9 T J Q K),
                  suit <- ~w(C D H S),
                  do: rank <> suit

  @card_positions [:deck, :table, :held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]
  def card_positions, do: @card_positions

  @num_decks_to_use 2
  @hand_size 6

  @max_players 4
  def max_players, do: @max_players

  def broadcast_game(game_id) when is_integer(game_id) do
    game = get_game_players_event(game_id)

    Phoenix.PubSub.broadcast(
      Golf.PubSub,
      "game:#{game_id}",
      {:game, game}
    )
  end

  def broadcast_chat_message(%ChatMessage{game_id: game_id} = message, username)
      when is_integer(game_id) do
    Phoenix.PubSub.broadcast(
      Golf.PubSub,
      "game:#{game_id}",
      {:chat_message, %{message | username: username}}
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

  defp flip_card(hand, index) do
    List.update_at(hand, index, fn card -> Map.put(card, "face_up?", true) end)
  end

  defp swap_card(hand, card_name, index) do
    old_card = Enum.at(hand, index) |> Map.get("name")
    hand = List.replace_at(hand, index, %{"name" => card_name, "face_up?" => true})
    {old_card, hand}
  end

  defp flip_all(hand) do
    Enum.map(hand, fn card -> Map.put(card, "face_up?", true) end)
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

  defp face_down_cards(hand) do
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

      s when s in [:take, :last_take] ->
        [:deck, :table]

      s when s in [:hold, :last_hold] ->
        [:held, :hand_0, :hand_1, :hand_2, :hand_3, :hand_4, :hand_5]

      _ ->
        []
    end
  end

  def playable_cards(%Game{}, %Player{}) do
    []
  end

  def rank_value(rank) when is_integer(rank) do
    case rank do
      ?K -> 0
      ?A -> 1
      ?2 -> 2
      ?3 -> 3
      ?4 -> 4
      ?5 -> 5
      ?6 -> 6
      ?7 -> 7
      ?8 -> 8
      ?9 -> 9
      r when r in [?T, ?J, ?Q] -> 10
    end
  end

  defp rank_totals(ranks, total) do
    case ranks do
      # all match
      [a, a, a, a, a, a] when is_integer(a) ->
        -40

      # outer cols match
      [a, b, a, a, c, a] when is_integer(a) ->
        rank_totals([b, c], total - 20)

      # left 2 cols match
      [a, a, b, a, a, c] when is_integer(a) ->
        rank_totals([b, c], total - 10)

      # right 2 cols match
      [a, b, b, c, b, b] when is_integer(b) ->
        rank_totals([a, c], total - 10)

      # left col match
      [a, b, c, a, d, e] when is_integer(a) ->
        rank_totals([b, c, d, e], total)

      # middle col match
      [a, b, c, d, b, e] when is_integer(b) ->
        rank_totals([a, c, d, e], total)

      # right col match
      [a, b, c, d, e, c] when is_integer(c) ->
        rank_totals([a, b, d, e], total)

      # left col match, 2nd pass
      [a, b, a, c] when is_integer(a) ->
        rank_totals([b, c], total)

      # right col match, 2nd pass
      [a, b, c, b] when is_integer(b) ->
        rank_totals([a, c], total)

      [a, a] when is_integer(a) ->
        total

      _ ->
        ranks
        |> Enum.reject(&is_nil/1)
        |> Enum.sum()
        |> Kernel.+(total)
    end
  end

  defp maybe_rank_value(%{"name" => <<rank, _>>, "face_up?" => true}), do: rank_value(rank)
  defp maybe_rank_value(_), do: nil

  def score(hand) do
    Enum.map(hand, &maybe_rank_value/1)
    |> rank_totals(0)
  end

  # game queries

  def get_game(game_id, opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])

    Repo.get(Game, game_id)
    |> Repo.preload(preloads)
  end

  def get_game_players_event(game_id) do
    player_query =
      from(
        p in Player,
        where: p.game_id == ^game_id,
        order_by: p.turn,
        join: u in User,
        on: u.id == p.user_id,
        select: %Player{p | username: u.username}
      )

    event_query =
      from(
        e in Event,
        where: e.game_id == ^game_id,
        order_by: [desc: e.inserted_at],
        limit: 1
      )

    Repo.get(Game, game_id)
    |> Repo.preload([players: player_query, events: event_query])
  end

  def get_chat_messages(game_id) do
    from(cm in ChatMessage,
      where: cm.game_id == ^game_id,
      join: u in User,
      on: u.id == cm.user_id,
      select: %ChatMessage{cm | username: u.username}
    )
    |> Repo.all()
  end

  def get_game_infos() do
    from(g in Game,
      where: g.status == :init,
      join: p in Player,
      on: p.game_id == g.id,
      where: p.host?,
      join: u in User,
      on: u.id == p.user_id,
      order_by: g.inserted_at,
      select: %{id: g.id, created_at: g.inserted_at, host_id: u.id, host_username: u.username}
    )
    |> Repo.all()
  end

  def get_player(player_id) do
    Repo.get(Player, player_id)
  end

  def get_players(game_id) do
    from(p in Player, where: p.game_id == ^game_id)
    |> Repo.all()
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

  def add_player_to_game(%Game{status: :init} = game, %User{} = user) do
    turn = length(game.players)

    {:ok, player} =
      Ecto.build_assoc(game, :players, %{user_id: user.id, turn: turn})
      |> Repo.insert()

    broadcast_game(game.id)
    {:ok, player}
  end

  def insert_chat_message(%ChatMessage{} = message, username) do
    {:ok, message} = Repo.insert(message)
    broadcast_chat_message(message, username)
    {:ok, message}
  end

  def start_game(%Game{status: :init} = game) do
    num_cards_to_deal = @hand_size * length(game.players)
    {card_names, deck} = Enum.split(game.deck, num_cards_to_deal)

    {:ok, card, deck} = deal_from_deck(deck)
    table_cards = [card | game.table_cards]

    hands =
      Enum.map(card_names, fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(@hand_size)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :game,
        Game.changeset(game, %{status: :flip2, deck: deck, table_cards: table_cards})
      )
      |> update_player_hands(game.players, hands)
      |> Repo.transaction()

    broadcast_game(game.id)
    {:ok, multi}
  end

  defp update_player_hands(multi, players, hands) do
    changesets =
      players
      |> Enum.zip(hands)
      |> Enum.map(fn {player, hand} -> Player.changeset(player, %{hand: hand}) end)

    Enum.reduce(changesets, multi, fn cs, multi ->
      Ecto.Multi.update(multi, {:player, cs.data.id}, cs)
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
        %Game{status: :last_take} = game,
        %Player{} = player,
        %Event{action: :take_from_deck} = event
      ) do
    {:ok, card, deck} = deal_from_deck(game.deck)

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: card}))
      |> Ecto.Multi.update(:game, Game.changeset(game, %{status: :last_hold, deck: deck}))
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
        %Game{status: :last_take} = game,
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
        Game.changeset(game, %{status: :last_hold, table_cards: table_cards})
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
        %Game{status: :last_hold} = game,
        %Player{} = player,
        %Event{action: :discard} = event
      ) do
    card = player.held_card
    table_cards = [card | game.table_cards]

    other_players = Enum.reject(game.players, fn p -> p.id == player.id end)

    {status, turn, hand} =
      if all_players_all_flipped?(other_players) do
        {:over, game.turn, flip_all(player.hand)}
      else
        {:last_take, game.turn + 1, player.hand}
      end

    {:ok, multi} =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:event, event)
      |> Ecto.Multi.update(:player, Player.changeset(player, %{held_card: nil, hand: hand}))
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
      ) do
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
end
