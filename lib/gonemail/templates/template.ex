defmodule Gonemail.Templates.Template do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  @foreign_key_type :string

  schema "templates" do
    field :subject, :string
    field :html_body, :string

    timestamps()
  end

  @required [:name, :subject, :html_body]

  def changeset(template, attrs) do
    template
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> unique_constraint(:name, name: :templates_pkey)
  end
end
