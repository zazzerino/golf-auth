defmodule Golf.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :user_id, references(:users, on_delete: :nothing)
      add :game_id, references(:games, on_delete: :delete_all)

      add :turn, :integer
      add :hand, {:array, :map}
      add :held_card, :string

      timestamps(updated_at: false)
    end

    create index(:players, [:user_id])
    create index(:players, [:game_id])
  end
end
