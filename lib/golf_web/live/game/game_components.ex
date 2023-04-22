defmodule GolfWeb.GameComponents do
  use GolfWeb, :html

  @game_width 600
  def game_width, do: @game_width

  @game_height 600
  def game_height, do: @game_height

  @game_viewbox "#{-@game_width / 2}, #{-@game_height / 2}, #{@game_width}, #{@game_height}"
  def game_viewbox, do: @game_viewbox

  @card_width 60
  def card_width, do: @card_width

  @card_height 84
  def card_height, do: @card_height

  @card_scale "10%"
  def card_scale, do: @card_scale

  @card_back "2B"
  def card_back, do: @card_back

  attr :name, :string, required: true
  attr :class, :string, default: nil
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :rest, :global

  def card_image(assigns) do
    ~H"""
    <image
      class={["card", @class]}
      href={"/images/cards/#{@name}.svg"}
      x={@x - card_width() / 2}
      y={@y - card_height() / 2}
      width={card_width()}
      {@rest}
    />
    """
  end

  def deck_x(:init), do: 0
  def deck_x(_), do: -@card_width / 2

  attr :game_status, :atom, required: true
  attr :playable, :boolean, required: true

  def deck(assigns) do
    ~H"""
    <.card_image
      class={if @playable, do: "highlight"}
      name={card_back()}
      x={deck_x(@game_status)}
      phx-value-playable={@playable}
      phx-click="deck_click"
    />
    """
  end

  def table_card_x, do: @card_width / 2

  attr :name, :string, required: true
  attr :playable, :boolean, required: true

  def table_card_0(assigns) do
    ~H"""
    <.card_image
      :if={@name}
      class={if @playable, do: "highlight"}
      name={@name}
      x={table_card_x()}
      phx-value-playable={@playable}
      phx-click="table_click"
    />
    """
  end

  attr :name, :string, required: true

  def table_card_1(assigns) do
    ~H"""
    <.card_image :if={@name} name={@name} x={table_card_x()} />
    """
  end

  attr :table_card_0, :string, required: true
  attr :table_card_1, :string, required: true
  attr :playable, :boolean, required: true

  def table_cards(assigns) do
    ~H"""
    <g id="table-cards">
      <.table_card_1 name={@table_card_1} />
      <.table_card_0 name={@table_card_0} playable={@playable} />
    </g>
    """
  end

  def hand_card_x(index) do
    case index do
      i when i in [0, 3] -> -@card_width
      i when i in [1, 4] -> 0
      i when i in [2, 5] -> @card_width
    end
  end

  def hand_card_y(index) do
    case index do
      i when i in 0..2 -> -@card_height / 2
      _ -> @card_height / 2
    end
  end

  def hand_positions(num_players) do
    case num_players do
      1 -> [:bottom]
      2 -> [:bottom, :top]
      3 -> [:bottom, :left, :right]
      4 -> [:bottom, :left, :top, :right]
    end
  end

  def hand_card_playable?(player_id, user_player_id, playable_cards, index)
      when player_id == user_player_id do
    card = String.to_existing_atom("hand_#{index}")
    card in playable_cards
  end

  def hand_card_playable?(_, _, _, _), do: false

  attr :cards, :list, required: true
  attr :position, :atom, required: true
  attr :player_id, :integer, required: true
  attr :user_player_id, :integer, required: true
  attr :playable_cards, :list, required: true

  def hand(assigns) do
    ~H"""
    <g class={"hand #{@position}"}>
      <%= for {card, index} <- Enum.with_index(@cards) do %>
        <.card_image
          class={
            if hand_card_playable?(@player_id, @user_player_id, @playable_cards, index),
              do: "highlight"
          }
          name={if card["face_up?"], do: card["name"], else: card_back()}
          x={hand_card_x(index)}
          y={hand_card_y(index)}
          phx-value-index={index}
          phx-value-player-id={@player_id}
          phx-value-user-player-id={@user_player_id}
          phx-value-face-up={card["face_up?"]}
          phx-click="hand_click"
        />
      <% end %>
    </g>
    """
  end

  attr :name, :string, required: true
  attr :position, :atom, required: true
  attr :playable, :boolean, required: true

  def held_card(assigns) do
    ~H"""
    <.card_image
      class={if @playable, do: "held #{@position} highlight", else: "held #{@position}"}
      name={@name}
      phx-value-playable={@playable}
      phx-click="held_click"
    />
    """
  end
end