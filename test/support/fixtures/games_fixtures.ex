defmodule Golf.GamesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Golf.Games` context.
  """

  @doc """
  Generate a game.
  """
  def game_fixture(attrs \\ %{}) do
    {:ok, game} =
      attrs
      |> Enum.into(%{
        deck: ["option1", "option2"],
        status: :init,
        table_cards: ["option1", "option2"],
        turn: 42
      })
      |> Golf.Games.create_game()

    game
  end
end
