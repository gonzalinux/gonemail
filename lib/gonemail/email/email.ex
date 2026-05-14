defmodule Gonemail.Email do
  import Swoosh.Email

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.{TemplateService, Renderer}
  alias Gonemail.Messages.MessageService

  def enqueue_email(to, app_id, template_id, from \\ nil, assigns \\ %{}) do
    with {:ok, app} <- AppService.get_verified_app(app_id),
         {:ok, template} <- TemplateService.get_template(template_id, app.default_template_id) do
      {to_email, to_name} = parse_recipient(to)
      {from_email, from_name} = parse_sender(from, app)
      {subject, html_body} = Renderer.render(template, assigns)

      MessageService.create(%{
        app_id: app.name,
        template_id: template.name,
        to_email: to_email,
        to_name: to_name,
        from_email: from_email,
        from_name: from_name,
        subject: subject,
        html_body: html_body,
        status: :queued
      })
    end
  end

  defp parse_recipient(email) when is_binary(email), do: {email, nil}
  defp parse_recipient({name, email}), do: {email, name}

  defp parse_sender(nil, app), do: {app.default_sender_email, app.default_sender_name}
  defp parse_sender({name, email}, _app), do: {email, name}

  @doc """
  Builds an email with provided body

  ## Parameters
    - to: Recipient email address or {name, email} tuple
    - subject: Email subject line
    - html: HTML body of the email
    - opts: Options including :from_email and :from_name

  ## Returns
    - A Swoosh.Email struct ready to be delivered
  """
  def build(
        to,
        subject,
        html,
        %{from_email: from_email, from_name: from_name}
      ) do
    text = extract_text_from_html(html)

    new()
    |> to(to)
    |> from({from_name, from_email})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
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
