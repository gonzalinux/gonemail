defmodule Gonemail.Email.Workers.EmailPool do
  use Supervisor

  @default_pool_size 5

  def start_link(opts) do
    pool_size =
      Keyword.get(
        opts,
        :pool_size,
        Application.get_env(:gonemail, :email_pool_size, @default_pool_size)
      )

    Supervisor.start_link(__MODULE__, pool_size, name: __MODULE__)
  end

  @impl true
  def init(pool_size) do
    children =
      for i <- 1..pool_size do
        Supervisor.child_spec({Gonemail.Email.Workers.EmailWorker, []}, id: {EmailWorker, i})
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
