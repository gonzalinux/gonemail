defmodule Gonemail.Apps.AppService do
  import Ecto.Query
  alias Gonemail.Repo
  alias Gonemail.Apps.App

  def get_app(id) do
    App
    |> Repo.get(id)
  end

  def get_verified_app(id) do
    App
    |> where([a], a.id == ^id and a.status == :verified)
    |> Repo.one()
  end

  def create_app(attrs) do
    %App{}
    |> App.changeset(attrs)
    |> Repo.insert()
  end

  def update_app(id, attrs) do
    App
    |> Repo.get(id)
    |> App.changeset(attrs)
    |> Repo.update()
  end

  def delete_app(id) do
    App
    |> Repo.get(id)
    |> Repo.delete()
  end

  def list_apps do
    App
    |> Repo.all()
  end
end
