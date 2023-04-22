defmodule Golf.Games.Event do
  use Golf.Schema
  import Ecto.Changeset

  schema "events" do
    belongs_to :game, Golf.Games.Game
    belongs_to :player, Golf.Games.Player

    field :action, Ecto.Enum, values: [:take_from_deck, :take_from_table, :swap, :discard, :flip]
    field :hand_index, :integer

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:game_id, :player_id, :action, :hand_index])
    |> validate_required([:game_id, :player_id, :action, :hand_index])
  end
end
