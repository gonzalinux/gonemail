defmodule GonemailWeb.PixelController do
  use GonemailWeb, :controller
  alias Gonemail.Messages.MessageService
  @external_resource "priv/pixel.png"
  @pixel_png File.read!("priv/pixel.png")

  def show(conn, _params) do
    conn
    |> put_resp_content_type("image/png")
    |> send_resp(200, @pixel_png)
  end
end
