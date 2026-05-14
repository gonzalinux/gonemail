defmodule Gonemail.Apps.AppService do
  alias Gonemail.Repo
  alias Gonemail.Apps.App

  def get_app(name) do
    App
    |> Repo.get(name)
  end

  def get_verified_app(name) do
    case Repo.get_by(App, name: name, status: :active) do
      nil -> {:error, :not_found}
      app -> {:ok, app}
    end
  end

  def create_app(attrs) do
    %App{}
    |> App.changeset(attrs)
    |> Repo.insert()
  end

  def update_app(name, attrs) do
    case Repo.get(App, name) do
      nil -> {:error, :not_found}
      app -> app |> App.changeset(attrs) |> Repo.update()
    end
  end

  def delete_app(name) do
    case Repo.get(App, name) do
      nil -> {:error, :not_found}
      app -> Repo.delete(app)
    end
  end

  def list_apps do
    App
    |> Repo.all()
  end
end
