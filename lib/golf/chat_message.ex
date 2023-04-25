defmodule Golf.ChatMessage do
  use Golf.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    belongs_to :user, Golf.Accounts.User
    belongs_to :game, Golf.Games.Game

    field :content, :string

    field :username, :string

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:user_id, :game_id, :content])
    |> validate_required([:user_id, :game_id, :content])
  end

  def content_changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_length(:content, min: 1)
  end
end
