defmodule GonemailWeb.Live.TemplatesLive do
  use GonemailWeb, :live_view

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.TemplateService

  @impl true
  def mount(%{"name" => app_name}, _session, socket) do
    case AppService.get_app(app_name) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/admin/apps")}

      app ->
        {:ok,
         assign(socket,
           app: app,
           templates: TemplateService.list_templates(app.name),
           editing: nil,
           error: nil
         )}
    end
  end

  @impl true
  def handle_event("create", %{"template" => params}, socket) do
    attrs = Map.put(params, "app_id", socket.assigns.app.name)

    case TemplateService.create_template(attrs) do
      {:ok, _template} ->
        {:noreply,
         assign(socket,
           templates: TemplateService.list_templates(socket.assigns.app.name),
           error: nil
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, error: format_errors(changeset))}
    end
  end

  def handle_event("edit_start", %{"name" => name}, socket) do
    {:noreply, assign(socket, editing: name)}
  end

  def handle_event("edit_cancel", _params, socket) do
    {:noreply, assign(socket, editing: nil)}
  end

  def handle_event("edit_save", %{"template" => params, "name" => name}, socket) do
    case TemplateService.update_template(name, params) do
      {:ok, _template} ->
        {:noreply,
         assign(socket,
           templates: TemplateService.list_templates(socket.assigns.app.name),
           editing: nil,
           error: nil
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, error: format_errors(changeset))}
    end
  end

  def handle_event("delete", %{"name" => name}, socket) do
    TemplateService.delete_template(name)
    {:noreply, assign(socket, templates: TemplateService.list_templates(socket.assigns.app.name))}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field}: #{Enum.join(msgs, ", ")}" end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-6 flex items-center gap-3">
        <a href={~p"/admin/apps"} class="text-sm text-gray-500 hover:text-gray-700">← Apps</a>
        <h1 class="text-2xl font-bold"><%= @app.name %> — Templates</h1>
        <span class={"px-2 py-0.5 rounded-full text-xs font-medium #{status_class(@app.status)}"}>
          <%= @app.status %>
        </span>
      </div>

      <%= if @error do %>
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm"><%= @error %></div>
      <% end %>

      <form phx-submit="create" class="mb-8 bg-white border border-gray-200 rounded-lg p-4">
        <h2 class="font-semibold mb-3 text-gray-700">New Template</h2>
        <div class="grid grid-cols-2 gap-3 mb-3">
          <input name="template[name]" placeholder="Name (e.g. welcome)" required
            class="border border-gray-300 rounded px-3 py-2 text-sm" />
          <input name="template[subject]" placeholder="Subject" required
            class="border border-gray-300 rounded px-3 py-2 text-sm" />
        </div>
        <textarea name="template[html_body]" placeholder="HTML body" required rows="5"
          class="border border-gray-300 rounded px-3 py-2 text-sm w-full font-mono mb-3"></textarea>
        <button type="submit"
          class="bg-blue-600 text-white text-sm px-4 py-2 rounded hover:bg-blue-700">
          Create
        </button>
      </form>

      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 border-b border-gray-200">
            <tr>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Name</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Subject</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for template <- @templates do %>
              <%= if @editing == template.name do %>
                <tr>
                  <td colspan="3" class="px-4 py-3">
                    <form phx-submit="edit_save" class="space-y-2">
                      <input type="hidden" name="name" value={template.name} />
                      <input name="template[subject]" value={template.subject} required
                        class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
                      <textarea name="template[html_body]" required rows="6"
                        class="border border-gray-300 rounded px-3 py-2 text-sm w-full font-mono"><%= template.html_body %></textarea>
                      <div class="flex gap-2">
                        <button type="submit"
                          class="bg-blue-600 text-white text-sm px-3 py-1.5 rounded hover:bg-blue-700">
                          Save
                        </button>
                        <button type="button" phx-click="edit_cancel"
                          class="text-sm text-gray-600 border border-gray-300 px-3 py-1.5 rounded hover:bg-gray-50">
                          Cancel
                        </button>
                      </div>
                    </form>
                  </td>
                </tr>
              <% else %>
                <tr class="hover:bg-gray-50">
                  <td class="px-4 py-3 font-medium"><%= template.name %></td>
                  <td class="px-4 py-3 text-gray-600"><%= template.subject %></td>
                  <td class="px-4 py-3 flex gap-2 justify-end">
                    <button phx-click="edit_start" phx-value-name={template.name}
                      class="text-xs text-gray-600 border border-gray-300 rounded px-2 py-1 hover:bg-gray-50">
                      Edit
                    </button>
                    <button phx-click="delete" phx-value-name={template.name}
                      data-confirm={"Delete #{template.name}?"}
                      class="text-xs text-red-600 border border-red-200 rounded px-2 py-1 hover:bg-red-50">
                      Delete
                    </button>
                  </td>
                </tr>
              <% end %>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_class(:active), do: "bg-green-100 text-green-700"
  defp status_class(:pending), do: "bg-yellow-100 text-yellow-700"
  defp status_class(:inactive), do: "bg-gray-100 text-gray-600"
end
