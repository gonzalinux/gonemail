defmodule Gonemail.Templates.Template do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  @foreign_key_type :string
  @derive {Jason.Encoder,
           only: [
             :name,
             :subject,
             :html_body,
             :default_sender_email,
             :default_sender_name,
             :app_id,
             :inserted_at,
             :updated_at
           ]}

  schema "templates" do
    field :subject, :string
    field :html_body, :string
    field :default_sender_email, :string
    field :default_sender_name, :string

    belongs_to :app, Gonemail.Apps.App,
      foreign_key: :app_id,
      references: :name,
      type: :string

    timestamps()
  end

  @required [:name, :subject, :html_body, :app_id]
  @optional [:default_sender_email, :default_sender_name]

  def changeset(template, attrs) do
    template
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:default_sender_email, ~r/@/, message: "is not a valid email address")
    |> assoc_constraint(:app)
    |> unique_constraint(:name, name: :templates_pkey)
  end
end
