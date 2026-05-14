defmodule Gonemail.Templates.TemplateServiceTest do
  use Gonemail.DataCase, async: true

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.TemplateService

  @app_attrs %{name: "myapp", domain: "myapp.com", status: "pending"}
  @valid_attrs %{name: "welcome", subject: "Welcome!", html_body: "<p>Hello</p>"}
  @invalid_attrs %{name: nil, subject: nil, html_body: nil}

  setup do
    {:ok, app} = AppService.create_app(@app_attrs)
    {:ok, app: app}
  end

  describe "create_template/1" do
    test "creates a template with valid attributes", %{app: app} do
      assert {:ok, template} =
               TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))

      assert template.name == "welcome"
      assert template.subject == "Welcome!"
      assert template.app_id == app.name
    end

    test "returns error with missing required fields" do
      assert {:error, changeset} = TemplateService.create_template(@invalid_attrs)

      assert %{
               name: ["can't be blank"],
               subject: ["can't be blank"],
               html_body: ["can't be blank"]
             } =
               errors_on(changeset)
    end

    test "returns error without app_id" do
      assert {:error, changeset} = TemplateService.create_template(@valid_attrs)
      assert %{app_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error on duplicate name", %{app: app} do
      attrs = Map.put(@valid_attrs, :app_id, app.name)
      TemplateService.create_template(attrs)
      assert {:error, changeset} = TemplateService.create_template(attrs)
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_template/1" do
    test "returns the template by name", %{app: app} do
      {:ok, template} = TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))
      assert TemplateService.get_template(template.name).name == template.name
    end

    test "returns nil for unknown name" do
      assert TemplateService.get_template("nonexistent") == nil
    end
  end

  describe "get_template/2" do
    test "returns template by id when given", %{app: app} do
      {:ok, template} = TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))
      assert {:ok, found} = TemplateService.get_template(template.name, nil)
      assert found.name == template.name
    end

    test "falls back to default_id when id is nil", %{app: app} do
      {:ok, template} = TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))
      assert {:ok, found} = TemplateService.get_template(nil, template.name)
      assert found.name == template.name
    end

    test "returns not_found when id is given but does not exist" do
      assert {:error, :not_found} = TemplateService.get_template("missing", nil)
    end

    test "returns not_found when both ids are nil" do
      assert {:error, :not_found} = TemplateService.get_template(nil, nil)
    end

    test "returns not_found when id is nil and default does not exist" do
      assert {:error, :not_found} = TemplateService.get_template(nil, "missing")
    end

    test "ignores default_id when id is given", %{app: app} do
      {:ok, t1} = TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))

      {:ok, t2} =
        TemplateService.create_template(%{
          name: "other",
          subject: "Other",
          html_body: "<p>Other</p>",
          app_id: app.name
        })

      assert {:ok, found} = TemplateService.get_template(t1.name, t2.name)
      assert found.name == t1.name
    end
  end

  describe "update_template/2" do
    test "updates a template with valid attributes", %{app: app} do
      {:ok, template} = TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))

      assert {:ok, updated} =
               TemplateService.update_template(template.name, %{subject: "Updated"})

      assert updated.subject == "Updated"
    end

    test "returns not_found for unknown name" do
      assert {:error, :not_found} =
               TemplateService.update_template("nonexistent", %{subject: "X"})
    end
  end

  describe "delete_template/1" do
    test "deletes an existing template", %{app: app} do
      {:ok, template} = TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))
      assert {:ok, _} = TemplateService.delete_template(template.name)
      assert TemplateService.get_template(template.name) == nil
    end

    test "returns not_found for unknown name" do
      assert {:error, :not_found} = TemplateService.delete_template("nonexistent")
    end
  end

  describe "list_templates/1" do
    test "returns templates for the given app", %{app: app} do
      TemplateService.create_template(Map.put(@valid_attrs, :app_id, app.name))

      TemplateService.create_template(%{
        name: "other",
        subject: "Other",
        html_body: "<p>Other</p>",
        app_id: app.name
      })

      assert length(TemplateService.list_templates(app.name)) == 2
    end

    test "does not return templates from other apps", %{app: app} do
      {:ok, other_app} =
        AppService.create_app(%{name: "otherapp", domain: "other.com", status: "pending"})

      TemplateService.create_template(Map.put(@valid_attrs, :app_id, other_app.name))

      assert TemplateService.list_templates(app.name) == []
    end

    test "returns empty list when app has no templates", %{app: app} do
      assert TemplateService.list_templates(app.name) == []
    end
  end
end
