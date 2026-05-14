defmodule Gonemail.Repo.Migrations.AddAppIdToTemplates do
  use Ecto.Migration

  def change do
    alter table(:templates) do
      add :app_id, references(:apps, on_delete: :delete_all, column: :name, type: :string),
        null: false
    end

    create index(:templates, [:app_id])
  end
end
