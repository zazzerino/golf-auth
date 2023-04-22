defmodule Golf.Games.Player do
  use Golf.Schema
  import Ecto.Changeset

  schema "players" do
    belongs_to :user, Golf.Accounts.User
    belongs_to :game, Golf.Games.Game

    has_many :events, Golf.Games.Event

    field :hand, {:array, :map}, default: []
    field :held_card, :string
    field :turn, :integer

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(player, attrs) do
    player
    |> cast(attrs, [:user_id, :game_id, :turn, :hand, :held_card])
    |> validate_required([:user_id, :game_id, :turn, :hand, :held_card])
  end
end
