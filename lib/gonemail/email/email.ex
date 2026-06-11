defmodule Gonemail.Email do
  import Swoosh.Email

  require Logger

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.{TemplateService, Renderer}
  alias Gonemail.Messages.MessageService

  def enqueue_email(to, app_id, template_id, from \\ nil, assigns \\ %{}, attachments \\ []) do
    with {:ok, app} <- AppService.get_verified_app(app_id),
         {:ok, template} <- TemplateService.get_template(template_id, app.default_template_id),
         {from_email, from_name} = parse_sender(from, template, app),
         :ok <- validate_sender_domain(from_email, app.domain),
         {:ok, {to_email, to_name}} <- parse_recipient(to) do
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
        attachments: attachments,
        status: :queued
      })
    else
      {:error, reason} ->
        Logger.warning(
          "Failed to enqueue email for app=#{app_id} template=#{template_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  defp parse_recipient(nil), do: {:error, :missing_recipient}
  defp parse_recipient(email) when is_binary(email), do: {:ok, {email, nil}}
  defp parse_recipient({name, email}), do: {:ok, {email, name}}

  defp parse_sender(nil, %{default_sender_email: email} = template, _app) when not is_nil(email),
    do: {email, template.default_sender_name}

  defp parse_sender(nil, _template, app), do: {app.default_sender_email, app.default_sender_name}
  defp parse_sender({name, email}, _template, _app), do: {email, name}
  defp parse_sender(email, _template, _app) when is_binary(email), do: {email, nil}

  defp validate_sender_domain(from_email, app_domain) do
    case String.split(from_email, "@") do
      [_, domain] ->
        if String.downcase(domain) == String.downcase(app_domain),
          do: :ok,
          else: {:error, :invalid_sender_domain}

      _ ->
        {:error, :invalid_sender_domain}
    end
  end

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
  def build(to, subject, html, %{from_email: from_email, from_name: from_name}, attachments \\ []) do
    text = extract_text_from_html(html)

    email =
      new()
      |> to(to)
      |> from({from_name, from_email})
      |> subject(subject)
      |> html_body(html)
      |> text_body(text)

    Enum.reduce(attachments, email, fn att, acc ->
      attachment(acc, build_attachment(att))
    end)
  end

  defp build_attachment(%{"filename" => filename, "content" => content} = att) do
    content_type = Map.get(att, "content_type", "application/octet-stream")
    data = Base.decode64!(content)

    Swoosh.Attachment.new({:data, data},
      filename: filename,
      content_type: content_type,
      type: :attachment
    )
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
