defmodule Gonemail.Templates.TemplateService do
  import Ecto.Query
  alias Gonemail.Repo
  alias Gonemail.Templates.Template

  def get_template(name) do
    Repo.get(Template, name)
  end

  # Fetches template_id if given, otherwise falls back to default_template_id.
  def get_template(nil, nil), do: {:error, :not_found}

  def get_template(nil, default_id) do
    case Repo.get(Template, default_id) do
      nil -> {:error, :not_found}
      template -> {:ok, template}
    end
  end

  def get_template(name, _default_name) do
    case Repo.get(Template, name) do
      nil -> {:error, :not_found}
      template -> {:ok, template}
    end
  end

  def create_template(attrs) do
    %Template{}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  def update_template(name, attrs) do
    case Repo.get(Template, name) do
      nil -> {:error, :not_found}
      template -> template |> Template.changeset(attrs) |> Repo.update()
    end
  end

  def delete_template(name) do
    case Repo.get(Template, name) do
      nil -> {:error, :not_found}
      template -> Repo.delete(template)
    end
  end

  def list_templates(app_name) do
    from(t in Template, where: t.app_id == ^app_name)
    |> Repo.all()
  end
end
