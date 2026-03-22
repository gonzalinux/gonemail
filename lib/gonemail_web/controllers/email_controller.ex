defmodule GonemailWeb.EmailController do
  use GonemailWeb, :controller

  def send(conn, _params) do

    conn
    |> put_status(:ok)
    |> json(%{message: "Email sent successfully"})

  end
end
