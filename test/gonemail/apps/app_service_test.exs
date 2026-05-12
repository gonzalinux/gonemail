defmodule Gonemail.Apps.AppServiceTest do
  use Gonemail.DataCase, async: true

  alias Gonemail.Apps.AppService

  @valid_attrs %{name: "seveneat", domain: "seveneat.com", status: "pending"}
  @invalid_attrs %{name: nil, domain: nil, status: nil}

  describe "create_app/1" do
    test "creates an app with valid attributes" do
      assert {:ok, app} = AppService.create_app(@valid_attrs)
      assert app.name == "seveneat"
      assert app.domain == "seveneat.com"
      assert app.status == "pending"
    end

    test "returns error with missing required fields" do
      assert {:error, changeset} = AppService.create_app(@invalid_attrs)
      assert %{name: ["can't be blank"], domain: ["can't be blank"], status: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "returns error with invalid status" do
      assert {:error, changeset} = AppService.create_app(%{@valid_attrs | status: "unknown"})
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "returns error on duplicate name" do
      AppService.create_app(@valid_attrs)
      assert {:error, changeset} = AppService.create_app(@valid_attrs)
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_app/1" do
    test "returns the app by name" do
      {:ok, app} = AppService.create_app(@valid_attrs)
      assert AppService.get_app(app.name).name == app.name
    end

    test "returns nil for unknown name" do
      assert AppService.get_app("nonexistent") == nil
    end
  end

  describe "update_app/2" do
    test "updates an app with valid attributes" do
      {:ok, app} = AppService.create_app(@valid_attrs)
      assert {:ok, updated} = AppService.update_app(app.name, %{domain: "updated.com"})
      assert updated.domain == "updated.com"
    end

    test "returns error with invalid attributes" do
      {:ok, app} = AppService.create_app(@valid_attrs)
      assert {:error, changeset} = AppService.update_app(app.name, %{status: "bad"})
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "delete_app/1" do
    test "deletes an existing app" do
      {:ok, app} = AppService.create_app(@valid_attrs)
      assert {:ok, _} = AppService.delete_app(app.name)
      assert AppService.get_app(app.name) == nil
    end
  end

  describe "list_apps/0" do
    test "returns all apps" do
      AppService.create_app(@valid_attrs)
      AppService.create_app(%{name: "other", domain: "other.com", status: "active"})
      assert length(AppService.list_apps()) == 2
    end

    test "returns empty list when no apps exist" do
      assert AppService.list_apps() == []
    end
  end
end
