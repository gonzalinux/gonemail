defmodule GoneMailClient do
  @moduledoc """
  HTTP client for the Gonemail transactional email service.

  Drop this file into `lib/` of your project and add `{:req, "~> 0.5"}` to your deps.

  ## Configuration

      config :my_app, GoneMailClient,
        base_url: "http://gonemail.internal",
        app: "my_app"

  ## Usage

      # Minimal — uses config for base_url and app
      GoneMailClient.send("user@example.com", "welcome")

      # With data (available as {{ data.name }} in the template)
      GoneMailClient.send("user@example.com", "welcome", data: %{name: "Alice"})

      # Named recipient
      GoneMailClient.send({"Alice", "alice@example.com"}, "welcome", data: %{name: "Alice"})

      # Custom sender (must match the app's registered domain)
      GoneMailClient.send("user@example.com", "alert",
        from: {"Alerts", "alerts@mycompany.com"},
        data: %{message: "CPU at 99%"}
      )

      # Override config per-call
      GoneMailClient.send("user@example.com", "welcome",
        base_url: "http://other-host",
        app: "other_app"
      )

      # Check delivery status
      {:ok, %{"status" => status}} = GoneMailClient.get_message(message_id)
  """

  @timeout 10_000

  @doc """
  Enqueues a transactional email.

  Returns `{:ok, %{"id" => id, "status" => "queued"}}` on success.

  ## Options

  - `:data` — map passed to the template as `{{ data.key }}`
  - `:from` — sender as `"email@example.com"` or `{"Name", "email@example.com"}`;
    omit to use the template/app default
  - `:app` — override the configured app name
  - `:base_url` — override the configured base URL
  """
  @spec send(contact(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def send(to, template, opts \\ []) do
    {base_url, opts} = Keyword.pop(opts, :base_url, config(:base_url))
    {app, opts} = Keyword.pop(opts, :app, config(:app))
    {from, opts} = Keyword.pop(opts, :from)
    {data, _} = Keyword.pop(opts, :data, %{})

    body =
      %{to: encode_contact(to), app: app, template: template, data: data}
      |> maybe_put(:from, from && encode_contact(from))

    case Req.post("#{base_url}/api/v1/send",
           json: body,
           receive_timeout: @timeout
         ) do
      {:ok, %{status: 202, body: resp}} -> {:ok, resp}
      {:ok, %{body: resp}} -> {:error, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Fetches the delivery status of a previously enqueued message.

  Returns `{:ok, message}` or `{:error, :not_found}`.
  """
  @spec get_message(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_message(id, opts \\ []) do
    base_url = Keyword.get(opts, :base_url, config(:base_url))

    case Req.get("#{base_url}/api/v1/messages/#{id}", receive_timeout: @timeout) do
      {:ok, %{status: 200, body: resp}} -> {:ok, resp}
      {:ok, %{status: 404}} -> {:error, :not_found}
      {:ok, %{body: resp}} -> {:error, resp}
      {:error, reason} -> {:error, reason}
    end
  end

  @typedoc "An email address or a `{name, email}` tuple."
  @type contact() :: String.t() | {String.t(), String.t()}

  defp encode_contact(email) when is_binary(email), do: email
  defp encode_contact({name, email}), do: %{name: name, email: email}

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # Change :my_app to your application's OTP name (the key used in config/*.exs).
  @otp_app :my_app

  defp config(key) do
    @otp_app
    |> Application.get_env(GoneMailClient, [])
    |> Keyword.get(key)
  end
end
