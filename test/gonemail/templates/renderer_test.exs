defmodule Gonemail.Templates.RendererTest do
  use ExUnit.Case, async: true

  alias Gonemail.Templates.Renderer

  defp template(subject, html_body) do
    %{subject: subject, html_body: html_body}
  end

  describe "render/2 — interpolation" do
    test "replaces a simple variable" do
      t = template("Hello {{ name }}", "<p>{{ name }}</p>")
      {subject, html} = Renderer.render(t, %{"name" => "Alice"})
      assert subject == "Hello Alice"
      assert html == "<p>Alice</p>"
    end

    test "replaces a nested variable" do
      t = template("{{ data.title }}", "<p>{{ data.title }}</p>")
      {subject, html} = Renderer.render(t, %{"data" => %{"title" => "Welcome"}})
      assert subject == "Welcome"
      assert html == "<p>Welcome</p>"
    end

    test "replaces multiple variables" do
      t = template("Hi {{ name }}", "<p>{{ greeting }}, {{ name }}</p>")
      {_subject, html} = Renderer.render(t, %{"name" => "Bob", "greeting" => "Hello"})
      assert html == "<p>Hello, Bob</p>"
    end

    test "missing variable silently returns empty string" do
      t = template("Hi {{ missing }}", "<p>{{ also.missing }}</p>")
      {subject, html} = Renderer.render(t, %{})
      assert subject == "Hi "
      assert html == "<p></p>"
    end

    test "accepts atom keys in assigns" do
      t = template("{{ greeting }}", "<p>{{ greeting }}</p>")
      {subject, html} = Renderer.render(t, %{greeting: "Hey"})
      assert subject == "Hey"
      assert html == "<p>Hey</p>"
    end

    test "handles body and data top-level keys" do
      t = template("{{ body.event }}", "<p>{{ data.username }}</p>")

      assigns = %{
        "body" => %{"event" => "signup"},
        "data" => %{"username" => "john"}
      }

      {subject, html} = Renderer.render(t, assigns)
      assert subject == "signup"
      assert html == "<p>john</p>"
    end

    test "leaves non-template content untouched" do
      t = template("Hello world", "<p>No variables here</p>")
      {subject, html} = Renderer.render(t, %{})
      assert subject == "Hello world"
      assert html == "<p>No variables here</p>"
    end

    test "handles whitespace inside braces" do
      t = template("{{  name  }}", "{{name}}")
      {subject, html} = Renderer.render(t, %{"name" => "Alice"})
      assert subject == "Alice"
      assert html == "Alice"
    end
  end
end
