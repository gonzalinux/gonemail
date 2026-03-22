defmodule GonemailWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  alias Gonemail.Auth.ApiKey

  @header_api_key "x-api-key"

  def init(opts), do: opts

  def call(conn, _opts) do
    with [raw_key] <- get_req_header(conn, @header_api_key),
         {:ok, key} <- ApiKey.validate(raw_key) do
      assign(conn, :current_api_key, key)
    else
      _ -> json(conn, %{error: "Unauthorized", details: "No valid credentials provided"})
    end
  end
end
