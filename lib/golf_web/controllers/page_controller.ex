defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def home(conn, _params) do
    games = Golf.Games.get_game_infos()
    render(conn, :home, page_title: "Home", games: games)
  end
end
