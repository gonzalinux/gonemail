defmodule Gonemail.Templates.Renderer do
  def render(template, assigns) do
    # Normalize assigns to string keys so {{ body.key }} and {{ data.key }} work
    # regardless of whether caller used atom or string keys.
    string_assigns = stringify_keys(assigns)

    subject = eval(template.subject, string_assigns)
    html_body = eval(template.html_body, string_assigns)

    {subject, html_body}
  end

  # Replaces {{ path.to.var }} directly with the value from assigns.
  # Missing paths return "". EEx tags (<%= %>) are left for eval_string.
  defp preprocess(content, assigns) do
    Regex.replace(~r/\{\{\s*([\w.]+)\s*\}\}/, content, fn _, path ->
      keys = String.split(path, ".")
      to_string(get_in(assigns, keys) || "")
    end)
  end

  defp eval(content, string_assigns) do
    content
    |> preprocess(string_assigns)
    |> EEx.eval_string(assigns: string_assigns)
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end
end
