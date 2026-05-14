defmodule GonemailWeb.TemplateController do
  use GonemailWeb, :controller

  action_fallback GonemailWeb.FallbackController

  alias Gonemail.Templates.TemplateService

  def index(conn, %{"app_id" => app_name}) do
    json(conn, %{templates: TemplateService.list_templates(app_name)})
  end

  def show(conn, %{"id" => name}) do
    case TemplateService.get_template(name) do
      nil -> {:error, :not_found}
      template -> json(conn, template)
    end
  end

  def create(conn, %{"app_id" => app_name} = params) do
    attrs = params |> Map.delete("app_id") |> Map.put("app_id", app_name)

    with {:ok, template} <- TemplateService.create_template(attrs) do
      conn |> put_status(:created) |> json(template)
    end
  end

  def update(conn, %{"id" => name} = params) do
    with {:ok, template} <-
           TemplateService.update_template(name, Map.drop(params, ["id", "app_id"])) do
      json(conn, template)
    end
  end

  def delete(conn, %{"id" => name}) do
    with {:ok, _} <- TemplateService.delete_template(name) do
      send_resp(conn, :no_content, "")
    end
  end
end
