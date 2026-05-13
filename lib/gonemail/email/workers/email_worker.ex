defmodule Gonemail.Email.Workers.EmailWorker do
  use GenServer
  require Logger

  alias Gonemail.Messages.MessageService
  alias Gonemail.Email.EmailService
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
            result = EmailService.deliver(message)
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
end
