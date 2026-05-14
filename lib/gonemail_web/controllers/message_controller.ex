defmodule GonemailWeb.MessageController do
  use GonemailWeb, :controller

  action_fallback GonemailWeb.FallbackController

  alias Gonemail.Messages.MessageService

  def show(conn, %{"id" => id}) do
    with {:ok, message} <- MessageService.get_message(id) do
      json(conn, message)
    end
  end
end
