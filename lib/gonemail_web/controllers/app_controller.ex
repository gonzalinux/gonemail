defmodule GonemailWeb.AppController do
  use GonemailWeb, :controller

  action_fallback GonemailWeb.FallbackController

  alias Gonemail.Apps.AppService

  def index(conn, _params) do
    json(conn, %{apps: AppService.list_apps()})
  end

  def show(conn, %{"id" => name}) do
    case AppService.get_app(name) do
      nil -> {:error, :not_found}
      app -> json(conn, app)
    end
  end

  def create(conn, params) do
    with {:ok, app} <- AppService.create_app(params) do
      conn |> put_status(:created) |> json(app)
    end
  end

  def update(conn, %{"id" => name} = params) do
    with {:ok, app} <- AppService.update_app(name, Map.delete(params, "id")) do
      json(conn, app)
    end
  end

  def delete(conn, %{"id" => name}) do
    with {:ok, _} <- AppService.delete_app(name) do
      send_resp(conn, :no_content, "")
    end
  end
end
