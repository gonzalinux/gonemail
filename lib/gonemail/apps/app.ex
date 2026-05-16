defmodule Gonemail.Apps.App do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:name, :string, autogenerate: false}
  @foreign_key_type :string
  @derive {Jason.Encoder,
           only: [
             :name,
             :domain,
             :status,
             :verify_date,
             :default_sender_email,
             :default_sender_name,
             :default_template_id,
             :inserted_at,
             :updated_at
           ]}

  schema "apps" do
    field :domain, :string
    field :status, Ecto.Enum, values: [:pending, :active, :inactive], default: :pending
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
    |> validate_sender_domain()
  end

  def verify_changeset(app, attrs) do
    app
    |> cast(attrs, [:status, :verify_date])
    |> validate_required([:status, :verify_date])
  end

  defp validate_sender_domain(changeset) do
    validate_sender_domain(changeset, get_field(changeset, :default_sender_email))
  end

  defp validate_sender_domain(changeset, nil), do: changeset

  defp validate_sender_domain(changeset, email) do
    domain = get_field(changeset, :domain)

    case String.split(email, "@") do
      [_, sender_domain] ->
        if String.downcase(sender_domain) == String.downcase(domain) do
          changeset
        else
          add_error(changeset, :default_sender_email, "domain must match app domain")
        end

      _ ->
        add_error(changeset, :default_sender_email, "is not a valid email address")
    end
  end
end
