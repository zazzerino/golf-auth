defmodule GolfWeb.HomeLive do
  use GolfWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      send(self(), :get_game_infos)
    end

    {:ok, assign(socket, page_title: "Home", games: [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>Golf</.header>

    <.table id="games" rows={@games} row_click={fn value -> JS.push("row_click", value: value) end}>
      <:col :let={game} label="Game Id"><%= game.id %></:col>
      <:col :let={game} label="Host"><%= game.host_username %></:col>
    </.table>

    <.simple_form :if={@current_user} for={%{}} action={~p"/games/create"}>
      <:actions>
        <.button>New Game</.button>
      </:actions>
    </.simple_form>
    """
  end

  @impl true
  def handle_info(:get_game_infos, socket) do
    games = Golf.Games.get_game_infos()
    {:noreply, assign(socket, games: games)}
  end

  @impl true
  def handle_event("row_click", %{"id" => game_id}, socket) do
    {:noreply, redirect(socket, to: ~p"/games/#{game_id}")}
  end
end
