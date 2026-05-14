defmodule Gonemail.Email.Workers.EmailWorker do
  use GenServer
  alias Gonemail.Mailer

  alias Gonemail.Messages.Message
  alias Gonemail.Email
  alias Gonemail.Messages.MessageService
  alias Gonemail.Repo

  @idle_interval 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    send(self(), :poll)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    result =
      Repo.transaction(fn ->
        case MessageService.claim_next() do
          nil ->
            :empty

          message ->
            result =
              case deliver(message) do
                {:ok, _} -> :ok
                {:error, reason} -> {:error, reason}
              end

            MessageService.mark_attempt(message, result)
            :processed
        end
      end)

    case result do
      {:ok, :empty} -> Process.send_after(self(), :poll, @idle_interval)
      _ -> send(self(), :poll)
    end

    {:noreply, state}
  end

  defp deliver(%Message{
         to_email: to_email,
         to_name: to_name,
         from_email: from_email,
         from_name: from_name,
         subject: subject,
         html_body: html_body
       }) do
    to = if to_name, do: {to_name, to_email}, else: to_email

    Email.build(to, subject, html_body, %{from_email: from_email, from_name: from_name})
    |> Mailer.deliver()
  end
end
