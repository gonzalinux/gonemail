defmodule Gonemail.Messages.MessageService do
  import Ecto.Query
  alias Gonemail.Messages.Message
  alias Gonemail.Repo

  def count_pending() do
    now = DateTime.utc_now()

    from(m in Message,
      where: m.status == :queued or (m.status == :retrying and m.next_attempt_at < ^now)
    )
    |> select([m], count(m.id))
    |> Repo.one()
  end

  def get_next() do
    now = DateTime.utc_now()

    from(m in Message,
      where: m.status == :queued or (m.status == :retrying and m.next_attempt_at < ^now)
    )
    |> order_by([m], asc: m.id)
    |> limit(1)
    |> Repo.one()
  end

  def claim_next() do
    now = DateTime.utc_now()

    from(m in Message,
      where: m.status == :queued or (m.status == :retrying and m.next_attempt_at <= ^now),
      order_by: [asc: m.inserted_at],
      limit: 1,
      lock: "FOR UPDATE SKIP LOCKED"
    )
    |> Repo.one()
  end

  def list_messages(filters \\ []) do
    app_id = Keyword.get(filters, :app_id)
    status = Keyword.get(filters, :status)

    from(m in Message, order_by: [desc: m.inserted_at], limit: 50)
    |> then(fn q -> if app_id, do: where(q, [m], m.app_id == ^app_id), else: q end)
    |> then(fn q -> if status, do: where(q, [m], m.status == ^status), else: q end)
    |> Repo.all()
  end

  def get_message(id) do
    case Repo.get(Message, id) do
      nil -> {:error, :not_found}
      message -> {:ok, message}
    end
  end

  def create(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @retry_delays [5, 30, 120]
  @max_attempts 3

  def mark_attempt(message, :ok) do
    message
    |> Message.delivery_changeset(%{
      status: :delivered,
      attempts: message.attempts + 1,
      sent_at: DateTime.utc_now()
    })
    |> Repo.update!()
  end

  def mark_attempt(message, {:error, reason}) do
    attempts = message.attempts + 1

    if attempts >= @max_attempts do
      message
      |> Message.delivery_changeset(%{
        status: :failed,
        attempts: attempts,
        last_error: inspect(reason)
      })
      |> Repo.update!()
    else
      delay = Enum.at(@retry_delays, attempts - 1, 120)
      next_attempt = DateTime.add(DateTime.utc_now(), delay, :second)

      message
      |> Message.delivery_changeset(%{
        status: :retrying,
        attempts: attempts,
        last_error: inspect(reason),
        next_attempt_at: next_attempt
      })
      |> Repo.update!()
    end
  end
end
