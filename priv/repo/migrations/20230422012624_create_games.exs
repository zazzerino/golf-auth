defmodule Golf.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games) do
      add :status, :string
      add :deck, {:array, :string}
      add :table_cards, {:array, :string}
      add :turn, :integer

      timestamps()
    end
  end
end
