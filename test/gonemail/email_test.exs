defmodule Gonemail.EmailTest do
  use Gonemail.DataCase, async: true

  alias Gonemail.Email
  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.TemplateService

  @app_attrs %{
    name: "myapp",
    domain: "myapp.com",
    status: "active",
    default_sender_email: "hello@myapp.com",
    default_sender_name: "MyApp"
  }

  @template_attrs %{
    name: "welcome",
    subject: "Welcome {{ data.name }}",
    html_body: "<p>Hello {{ data.name }}</p>"
  }

  setup do
    {:ok, app} = AppService.create_app(@app_attrs)
    {:ok, template} = TemplateService.create_template(Map.put(@template_attrs, :app_id, app.name))
    {:ok, app: app, template: template}
  end

  describe "enqueue_email/5" do
    test "creates a queued message with rendered template", %{app: app, template: template} do
      assigns = %{"data" => %{"name" => "Alice"}}

      assert {:ok, msg} =
               Email.enqueue_email("alice@example.com", app.name, template.name, nil, assigns)

      assert msg.status == :queued
      assert msg.to_email == "alice@example.com"
      assert msg.subject == "Welcome Alice"
      assert msg.html_body == "<p>Hello Alice</p>"
      assert msg.from_email == "hello@myapp.com"
      assert msg.from_name == "MyApp"
      assert msg.template_id == template.name
    end

    test "uses app default template when template_id is nil", %{app: app, template: template} do
      {:ok, app} = AppService.update_app(app.name, %{default_template_id: template.name})

      assert {:ok, msg} = Email.enqueue_email("user@example.com", app.name, nil)

      assert msg.template_id == template.name
    end

    test "accepts {name, email} tuple as recipient", %{app: app, template: template} do
      assert {:ok, msg} =
               Email.enqueue_email({"Alice", "alice@example.com"}, app.name, template.name)

      assert msg.to_email == "alice@example.com"
      assert msg.to_name == "Alice"
    end

    test "accepts {name, email} tuple as sender override", %{app: app, template: template} do
      assert {:ok, msg} =
               Email.enqueue_email(
                 "alice@example.com",
                 app.name,
                 template.name,
                 {"Custom Sender", "custom@myapp.com"}
               )

      assert msg.from_email == "custom@myapp.com"
      assert msg.from_name == "Custom Sender"
    end

    test "returns error for inactive app", %{template: template} do
      {:ok, inactive} =
        AppService.create_app(%{name: "inactive", domain: "x.com", status: "pending"})

      assert {:error, :not_found} =
               Email.enqueue_email("u@example.com", inactive.name, template.name)
    end

    test "returns error for unknown app", %{template: template} do
      assert {:error, :not_found} = Email.enqueue_email("u@example.com", "ghost", template.name)
    end

    test "returns error when no template and no app default", %{app: app} do
      assert {:error, :not_found} = Email.enqueue_email("u@example.com", app.name, nil)
    end

    test "returns error for unknown template", %{app: app} do
      assert {:error, :not_found} =
               Email.enqueue_email("u@example.com", app.name, "nonexistent")
    end
  end
end
