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

  @num_decks_to_use 2
  @max_players 4
  @hand_size 6

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

  def playable_cards(%Game{}, %Player{}) do
    []
  end

  def current_player_turn(%Game{}) do
    0
  end

  # game queries

  def get_game(game_id, opts \\ []) do
    preloads = Keyword.get(opts, :preloads, [])

    Repo.get(Game, game_id)
    |> Repo.preload(preloads)
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

    game_changeset =
      game
      |> Game.changeset(%{status: :flip2, deck: deck, table_cards: table_cards})

    hands =
      Enum.map(card_names, fn name -> %{"name" => name, "face_up?" => false} end)
      |> Enum.chunk_every(@hand_size)

    player_changesets =
      game.players
      |> Enum.zip(hands)
      |> Enum.map(fn {player, hand} -> Player.changeset(player, %{hand: hand}) end)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:game, game_changeset)
    |> update_players(player_changesets)
    |> Repo.transaction()
  end

  defp update_players(multi, player_changesets) do
    Enum.reduce(player_changesets, multi, fn player_cs, multi ->
      Ecto.Multi.update(multi, {:player, player_cs.data.id}, player_cs)
    end)
  end

  def handle_game_event(%Game{} = game, %Player{}, %Event{}) do
    game
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
