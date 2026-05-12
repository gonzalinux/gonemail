defmodule Gonemail.Email.Email do
  import Swoosh.Email

  @doc """
  Builds an email using a HEEx template.

  ## Parameters
    - to: Recipient email address or {name, email} tuple
    - subject: Email subject line
    - template: Template module (e.g., Seveneat.Emails.Templates.Welcome)
    - assigns: Map of variables to pass to the template
    - opts: Options including :from_email (defaults to "noreply@seveneat.com")

  ## Returns
    - A Swoosh.Email struct ready to be delivered
  """
  def build(to, subject, template, assigns \\ %{}, opts \\ []) do
    html = render_template(template, assigns)
    text = extract_text_from_html(html)
    from_email = Keyword.get(opts, :from_email, "noreply@seveneat.com")
    from_name = Keyword.get(opts, :from_name, from_email)

    new()
    |> to(to)
    |> from({from_name, from_email})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  @doc """
  Renders a HEEx template module to HTML string.
  """
  def render_template(template, assigns) do
    template.render(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  # Simple text extraction from HTML (removes tags)
  defp extract_text_from_html(html) do
    html
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
