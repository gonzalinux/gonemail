defmodule Gonemail.Repo.Migrations.CreateApps do
  use Ecto.Migration

  def change do
    create table(:apps, primary_key: false) do
      add(:name, :string, primary_key: true, null: false)
      add(:domain, :string, null: false)
      add(:status, :string, null: false)
      add(:verify_date, :utc_datetime)
      add(:default_sender_email, :string)
      add(:default_sender_name, :string)

      add(
        :default_template_id,
        references(:templates, on_delete: :nilify_all, column: :name, type: :string)
      )

      timestamps()
    end

    create index(:apps, [:status, :verify_date])
  end
end
