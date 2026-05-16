defmodule GonemailWeb.Live.SendLive do
  use GonemailWeb, :live_view

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.TemplateService
  alias Gonemail.Email

  @impl true
  def mount(_params, _session, socket) do
    apps = AppService.list_apps() |> Enum.filter(&(&1.status == :active))

    {:ok,
     assign(socket,
       apps: apps,
       templates: [],
       result: nil,
       error: nil
     )}
  end

  @impl true
  def handle_event("app_selected", %{"app" => app_id}, socket) do
    templates = if app_id != "", do: TemplateService.list_templates(app_id), else: []
    {:noreply, assign(socket, templates: templates, result: nil, error: nil)}
  end

  def handle_event("send", params, socket) do
    app_id = params["app"]
    template_id = params["template"]
    to_email = params["to_email"]
    to_name = params["to_name"]
    data_raw = params["data"] || "{}"

    to = if to_name != "", do: {to_name, to_email}, else: to_email

    assigns =
      case Jason.decode(data_raw) do
        {:ok, map} -> %{"data" => map}
        {:error, _} -> %{"data" => %{}}
      end

    case Email.enqueue_email(to, app_id, template_id, nil, assigns) do
      {:ok, message} ->
        {:noreply, assign(socket, result: message.id, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, error: format_error(reason), result: nil)}
    end
  end

  defp format_error(:not_found), do: "App or template not found"

  defp format_error(changeset) when is_struct(changeset, Ecto.Changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  defp format_error(reason), do: inspect(reason)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-xl">
      <h1 class="text-2xl font-bold mb-6">Send Test Email</h1>

      <%= if @result do %>
        <div class="mb-4 p-3 bg-green-50 border border-green-200 rounded text-green-700 text-sm">
          Queued — message ID: <span class="font-mono"><%= @result %></span>
        </div>
      <% end %>

      <%= if @error do %>
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm"><%= @error %></div>
      <% end %>

      <form phx-submit="send" class="bg-white border border-gray-200 rounded-lg p-4 space-y-3">
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">App</label>
          <select name="app" phx-change="app_selected" class="border border-gray-300 rounded px-3 py-2 text-sm w-full" required>
            <option value="">Select an app…</option>
            <%= for app <- @apps do %>
              <option value={app.name}><%= app.name %></option>
            <% end %>
          </select>
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Template</label>
          <select name="template" class="border border-gray-300 rounded px-3 py-2 text-sm w-full" required>
            <option value="">Select a template…</option>
            <%= for t <- @templates do %>
              <option value={t.name}><%= t.name %> — <%= t.subject %></option>
            <% end %>
          </select>
        </div>

        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">To email</label>
            <input name="to_email" type="email" required
              class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">To name (optional)</label>
            <input name="to_name"
              class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
          </div>
        </div>

        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Data (JSON)</label>
          <textarea name="data" rows="4" placeholder="{}"
            class="border border-gray-300 rounded px-3 py-2 text-sm w-full font-mono">{}</textarea>
        </div>

        <button type="submit"
          class="bg-blue-600 text-white text-sm px-4 py-2 rounded hover:bg-blue-700">
          Send
        </button>
      </form>
    </div>
    """
  end
end
