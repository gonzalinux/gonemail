defmodule Gonemail.Messages.MessageServiceTest do
  use Gonemail.DataCase, async: true

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.TemplateService
  alias Gonemail.Messages.MessageService

  @app_attrs %{name: "testapp", domain: "test.com", status: "active"}
  @template_attrs %{name: "welcome", subject: "Welcome", html_body: "<p>Hello</p>"}

  setup do
    {:ok, app} = AppService.create_app(@app_attrs)
    {:ok, template} = TemplateService.create_template(Map.put(@template_attrs, :app_id, app.name))
    {:ok, app: app, template: template}
  end

  defp valid_message(app, template) do
    %{
      app_id: app.name,
      template_id: template.name,
      to_email: "user@example.com",
      from_email: "sender@test.com",
      subject: "Hello",
      html_body: "<p>Hi</p>",
      status: :queued
    }
  end

  describe "create/1" do
    test "creates a message with valid attributes", %{app: app, template: template} do
      assert {:ok, msg} = MessageService.create(valid_message(app, template))
      assert msg.app_id == app.name
      assert msg.template_id == template.name
      assert msg.to_email == "user@example.com"
      assert msg.status == :queued
      assert msg.attempts == 0
    end

    test "accepts optional to_name and from_name", %{app: app, template: template} do
      attrs = valid_message(app, template) |> Map.merge(%{to_name: "Alice", from_name: "Sender"})
      assert {:ok, msg} = MessageService.create(attrs)
      assert msg.to_name == "Alice"
      assert msg.from_name == "Sender"
    end

    test "returns error with missing required fields" do
      assert {:error, changeset} = MessageService.create(%{})
      errors = errors_on(changeset)
      assert errors[:to_email]
      assert errors[:from_email]
      assert errors[:status]
    end

    test "returns error with invalid email format", %{app: app, template: template} do
      attrs = valid_message(app, template) |> Map.put(:to_email, "notanemail")
      assert {:error, changeset} = MessageService.create(attrs)
      assert %{to_email: ["has invalid format"]} = errors_on(changeset)
    end

    test "returns error with nonexistent app" do
      attrs = %{
        app_id: "ghost",
        to_email: "user@example.com",
        from_email: "sender@test.com",
        subject: "Hi",
        html_body: "<p>Hi</p>",
        status: :queued
      }

      assert {:error, changeset} = MessageService.create(attrs)
      assert %{app: ["does not exist"]} = errors_on(changeset)
    end
  end
end
