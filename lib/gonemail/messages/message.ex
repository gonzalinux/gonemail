defmodule Gonemail.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :to_email, :string
    field :from_name, :string
    field :from_email, :string
    field :subject, :string
    field :body, :string
    field :data, :map
    field :status, :string
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

  @required [:app, :to_email, :from_email, :subject, :body, :status]
  @optional [:from_name, :data, :template_id, :last_error, :sent_at, :next_attempt_at]
  @statuses [:queued, :retrying, :delivered, :failed]

  def changeset(message, attrs) do
    message
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> validate_format(:to_email, ~r/@/)
    |> validate_format(:from_email, ~r/@/)
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:app)
    |> assoc_constraint(:template)
  end

  def delivery_changeset(message, attrs) do
    message
    |> cast(attrs, [:status, :attempts, :last_error, :sent_at, :next_attempt_at])
    |> validate_required([:status, :attempts])
    |> validate_inclusion(:status, @statuses)
  end
end
