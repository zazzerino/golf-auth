defmodule GolfWeb.GameController do
  use GolfWeb, :controller

  def create_game(%{assigns: %{current_user: user}} = conn, _) when is_struct(user) do
    {:ok, %{game: game}} = Golf.Games.create_game(user)
    redirect(conn, to: ~p"/games/#{game.id}")
  end
end
