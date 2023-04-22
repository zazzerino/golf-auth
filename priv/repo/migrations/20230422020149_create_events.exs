defmodule Golf.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :game_id, references(:games, on_delete: :delete_all)
      add :player_id, references(:players)

      add :action, :string
      add :hand_index, :integer

      timestamps(updated_at: false)
    end

    create index(:events, [:game_id])
    create index(:events, [:player_id])
  end
end
