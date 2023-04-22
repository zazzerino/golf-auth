defmodule Golf.GamesTest do
  use Golf.DataCase
  import Golf.AccountsFixtures
  alias Golf.Games

  describe "games" do
    alias Golf.Games.Game

    test "create_game/1" do
      user = user_fixture()

      {:ok, %{game: game}} = Games.create_game(user)

      game = Games.get_game(game.id, preloads: [:players])
      Games.start_game(game)

      Games.get_game(game.id, preloads: [:players])
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
