defmodule GonemailWeb.EmailController do
  use GonemailWeb, :controller

  action_fallback GonemailWeb.FallbackController

  alias Gonemail.Email

  require Logger

  def send(conn, params) do
    to = parse_contact(params["to"])
    from = parse_contact(params["from"])
    assigns = Map.merge(%{"body" => params}, params["data"] || %{})
    attachments = params["attachments"] || []

    Logger.info("Enqueueing send request for app=#{params["app"]} template=#{params["template"]}")

    with {:ok, message} <-
           Email.enqueue_email(to, params["app"], params["template"], from, assigns, attachments) do
      conn |> put_status(:accepted) |> json(%{id: message.id, status: message.status})
    end
  end

  defp parse_contact(nil), do: nil
  defp parse_contact(value) when is_binary(value), do: value
  defp parse_contact(%{"name" => name, "email" => email}), do: {name, email}
  defp parse_contact(%{"email" => email}), do: email
end
