defmodule Golf.Games.Game do
  use Golf.Schema
  import Ecto.Changeset

  schema "games" do
    field :status, Ecto.Enum,
      values: [:init, :flip2, :take, :hold, :flip, :last_take, :last_hold, :last_flip, :over]

    field :deck, {:array, :string}
    field :table_cards, {:array, :string}
    field :turn, :integer

    has_many :players, Golf.Games.Player
    has_many :events, Golf.Games.Event
    has_many :chat_messages, Golf.ChatMessage

    timestamps()
  end

  @doc false
  def changeset(game, attrs) do
    game
    |> cast(attrs, [:status, :deck, :table_cards, :turn])
    |> validate_required([:status, :deck, :table_cards, :turn])
  end
end
