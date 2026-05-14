defmodule Gonemail.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :app_id,
             :template_id,
             :to_email,
             :to_name,
             :from_email,
             :from_name,
             :subject,
             :status,
             :attempts,
             :last_error,
             :sent_at,
             :next_attempt_at,
             :inserted_at,
             :updated_at
           ]}

  schema "messages" do
    field :to_email, :string
    field :to_name, :string
    field :from_name, :string
    field :from_email, :string
    field :subject, :string
    field :html_body, :string
    field :data, :map
    field :status, Ecto.Enum, values: [:queued, :retrying, :delivered, :failed]
    field :attempts, :integer, default: 0
    field :last_error, :string
    field :sent_at, :utc_datetime
    field :next_attempt_at, :utc_datetime

    belongs_to :app, Gonemail.Apps.App,
      foreign_key: :app_id,
      references: :name,
      type: :string

    belongs_to :template, Gonemail.Templates.Template,
      foreign_key: :template_id,
      references: :name,
      type: :string

    timestamps()
  end

  @required [:app_id, :to_email, :from_email, :subject, :html_body, :status]
  @optional [:to_name, :from_name, :data, :template_id, :last_error, :sent_at, :next_attempt_at]

  def changeset(message, attrs) do
    message
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:to_email, ~r/@/)
    |> validate_format(:from_email, ~r/@/)
    |> assoc_constraint(:app)
    |> assoc_constraint(:template)
  end

  def delivery_changeset(message, attrs) do
    message
    |> cast(attrs, [:status, :attempts, :last_error, :sent_at, :next_attempt_at])
    |> validate_required([:status, :attempts])
  end
end
