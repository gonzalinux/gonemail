defmodule Gonemail.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :app, references(:apps, on_delete: :nothing, column: :name, type: :string), null: false
      add :to_email, :string, null: false
      add :from_name, :string
      add :from_email, :string, null: false
      add :subject, :text, null: false
      add :html_body, :text, null: false
      add :data, :json
      add :template_id, references(:templates, on_delete: :nothing, column: :name, type: :string)
      add :status, :string, null: false
      add :attempts, :integer, null: false, default: 0
      add :last_error, :text
      add :sent_at, :utc_datetime
      add :next_attempt_at, :utc_datetime
      timestamps()
    end

    create index(:messages, [:status, :next_attempt_at, :inserted_at])
    create index(:messages, [:app, :status])
  end
end
