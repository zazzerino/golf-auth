defmodule Golf.GamesTest do
  use Golf.DataCase
  import Golf.AccountsFixtures
  alias Golf.Games
  alias Golf.Games.{Event}

  describe "games" do
    alias Golf.Games.Game

    defp get_game(game_id) do
      Games.get_game_players_event(game_id)
    end

    test "two players" do
      user0 = user_fixture()
      user1 = user_fixture()

      {:ok, %{game: game, player: player0}} = Games.create_game(user0)

      game = get_game(game.id)
      {:ok, player1} = Games.add_player_to_game(game, user1)

      game = get_game(game.id)
      assert game.status == :init

      {:ok, _} = Games.start_game(game)

      player0 = Games.get_player(player0.id)
      player1 = Games.get_player(player1.id)

      game = get_game(game.id)
      assert game.status == :flip2

      # card 0

      event = Event.flip(game.id, player0.id, 0)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :flip2

      game = get_game(game.id)
      event = Event.flip(game.id, player1.id, 0)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :flip2

      # card 1

      game = get_game(game.id)
      event = Event.flip(game.id, player0.id, 1)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :flip2

      game = get_game(game.id)
      event = Event.flip(game.id, player1.id, 1)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      # card 2

      assert game.status == :take
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.take_from_deck(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.discard(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :flip
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.flip(game.id, player0.id, 2)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.take_from_table(game.id, player1.id)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.swap(game.id, player1.id, 2)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 0

      # card 3

      game = get_game(game.id)
      event = Event.take_from_table(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.swap(game.id, player0.id, 3)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.take_from_deck(game.id, player1.id)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.swap(game.id, player1.id, 3)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 0

      # card 4

      game = get_game(game.id)
      event = Event.take_from_table(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.swap(game.id, player0.id, 4)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.take_from_deck(game.id, player1.id)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.swap(game.id, player1.id, 4)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 0

      # card 5

      game = get_game(game.id)
      event = Event.take_from_deck(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.discard(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :take
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.take_from_table(game.id, player1.id)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :hold
      assert Games.current_player_turn(game) == 1

      game = get_game(game.id)
      event = Event.swap(game.id, player1.id, 5)
      {:ok, %{game: game, player: player1}} = Games.handle_game_event(game, player1, event)

      assert game.status == :last_take
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.take_from_deck(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      assert game.status == :last_hold
      assert Games.current_player_turn(game) == 0

      game = get_game(game.id)
      event = Event.discard(game.id, player0.id)
      {:ok, %{game: game, player: player0}} = Games.handle_game_event(game, player0, event)

      get_game(game.id)
      |> IO.inspect()
    end
  end

  # describe "games" do
  #   alias Golf.Games.Game

  #   import Golf.GamesFixtures

  #   @invalid_attrs %{deck: nil, status: nil, table_cards: nil, turn: nil}

  #   test "list_games/0 returns all games" do
  #     game = game_fixture()
  #     assert Games.list_games() == [game]
  #   end

  #   test "get_game!/1 returns the game with given id" do
  #     game = game_fixture()
  #     assert Games.get_game!(game.id) == game
  #   end

  #   test "create_game/1 with valid data creates a game" do
  #     valid_attrs = %{deck: ["option1", "option2"], status: :init, table_cards: ["option1", "option2"], turn: 42}

  #     assert {:ok, %Game{} = game} = Games.create_game(valid_attrs)
  #     assert game.deck == ["option1", "option2"]
  #     assert game.status == :init
  #     assert game.table_cards == ["option1", "option2"]
  #     assert game.turn == 42
  #   end

  #   test "create_game/1 with invalid data returns error changeset" do
  #     assert {:error, %Ecto.Changeset{}} = Games.create_game(@invalid_attrs)
  #   end

  #   test "update_game/2 with valid data updates the game" do
  #     game = game_fixture()
  #     update_attrs = %{deck: ["option1"], status: :flip2, table_cards: ["option1"], turn: 43}

  #     assert {:ok, %Game{} = game} = Games.update_game(game, update_attrs)
  #     assert game.deck == ["option1"]
  #     assert game.status == :flip2
  #     assert game.table_cards == ["option1"]
  #     assert game.turn == 43
  #   end

  #   test "update_game/2 with invalid data returns error changeset" do
  #     game = game_fixture()
  #     assert {:error, %Ecto.Changeset{}} = Games.update_game(game, @invalid_attrs)
  #     assert game == Games.get_game!(game.id)
  #   end

  #   test "delete_game/1 deletes the game" do
  #     game = game_fixture()
  #     assert {:ok, %Game{}} = Games.delete_game(game)
  #     assert_raise Ecto.NoResultsError, fn -> Games.get_game!(game.id) end
  #   end

  #   test "change_game/1 returns a game changeset" do
  #     game = game_fixture()
  #     assert %Ecto.Changeset{} = Games.change_game(game)
  #   end
  # end
end
