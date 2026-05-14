defmodule Gonemail.Apps.App do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  @foreign_key_type :string

  schema "apps" do
    field :domain, :string
    field :status, Ecto.Enum, values: [:pending, :active, :inactive]
    field :verify_date, :utc_datetime
    field :default_sender_email, :string
    field :default_sender_name, :string

    belongs_to :default_template, Gonemail.Templates.Template,
      foreign_key: :default_template_id,
      references: :name,
      type: :string

    has_many :templates, Gonemail.Templates.Template, foreign_key: :app_id
    has_many :messages, Gonemail.Messages.Message, foreign_key: :app_id

    timestamps()
  end

  @required [:name, :domain, :status]
  @optional [:verify_date, :default_sender_email, :default_sender_name, :default_template_id]

  def changeset(app, attrs) do
    app
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:name, name: :apps_pkey)
  end

  def verify_changeset(app, attrs) do
    app
    |> cast(attrs, [:status, :verify_date])
    |> validate_required([:status, :verify_date])
  end
end
