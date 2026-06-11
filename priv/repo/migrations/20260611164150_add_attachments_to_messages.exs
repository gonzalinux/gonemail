defmodule Gonemail.Repo.Migrations.AddAttachmentsToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :attachments, {:array, :map}, default: [], null: false
    end
  end
end
