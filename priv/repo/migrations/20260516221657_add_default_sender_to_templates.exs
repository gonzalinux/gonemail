defmodule Gonemail.Repo.Migrations.AddDefaultSenderToTemplates do
  use Ecto.Migration

  def change do
    alter table(:templates) do
      add :default_sender_email, :string
      add :default_sender_name, :string
    end
  end
end
