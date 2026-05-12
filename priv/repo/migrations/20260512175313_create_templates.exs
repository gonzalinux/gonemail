defmodule Gonemail.Repo.Migrations.CreateTemplates do
  use Ecto.Migration

  def change do
    create table(:templates, primary_key: false) do
      add(:name, :string, primary_key: true, null: false)
      add :subject, :text, null: false
      add :html_body, :text, null: false
      timestamps()
    end
  end
end
