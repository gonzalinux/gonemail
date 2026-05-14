defmodule Gonemail.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    case Application.get_env(:gonemail, :json_logging) do
      [enabled: true, path: path] -> Gonemail.JsonLogHandler.attach(path)
      _ -> :ok
    end

    children = [
      GonemailWeb.Telemetry,
      Gonemail.Repo,
      {DNSCluster, query: Application.get_env(:gonemail, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Gonemail.PubSub},
      # Start a worker by calling: Gonemail.Worker.start_link(arg)
      # {Gonemail.Worker, arg},
      {Gonemail.Email.Workers.EmailPool, []},
      # Start to serve requests, typically the last entry
      GonemailWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gonemail.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GonemailWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
