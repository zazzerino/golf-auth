defmodule GolfWeb.GameLive do
  use GolfWeb, :live_view
  import GolfWeb.GameComponents
  alias Golf.Games

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

  defp assign_game_data(%{assigns: %{current_user: user}} = socket, game)
      when is_struct(user) do
    user_index = Enum.find_index(game.players, &(&1.user_id == user.id))
    user_player = user_index && Enum.at(game.players, user_index)
    can_start_game? = user_player && user_player.host? && game.status == :init

    assign(socket,
      game: game,
      user_player: user_player,
      can_start_game?: can_start_game?
    )
  end

  defp assign_game_data(socket, game) do
    assign(socket,
      game: game
    )
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
end
