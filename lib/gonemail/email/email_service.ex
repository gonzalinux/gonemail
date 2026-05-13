defmodule Gonemail.Email.EmailService do

alias DBConnection.App
alias Gonemail.Apps.AppService
alias Gonemail.Templates.TemplateService
alias Gonemail.Email.Email
  def send_email(to, app, template_id, from) do
    with {:ok, app} <- AppService.get_verified_app(app),
    {:ok, template} <- TemplateService.get_template(template_id, app.default_template_id)do


    end
  end

  defp from(app, from) do

  end
end
