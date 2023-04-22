defmodule Golf.Repo.Migrations.AddHostToPlayers do
  use Ecto.Migration

  def change do
    alter table :players do
      add :host?, :boolean
    end
  end
end
