defmodule GonemailWeb.Live.AppsLive do
  use GonemailWeb, :live_view

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.TemplateService

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       apps: AppService.list_apps(),
       editing_app: nil,
       edit_templates: [],
       error: nil
     )}
  end

  @impl true
  def handle_event("create", %{"app" => params}, socket) do
    case AppService.create_app(params) do
      {:ok, _app} ->
        {:noreply, assign(socket, apps: AppService.list_apps(), error: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, error: format_errors(changeset))}
    end
  end

  def handle_event("open_edit", %{"name" => name}, socket) do
    app = AppService.get_app(name)
    templates = TemplateService.list_templates(name)
    {:noreply, assign(socket, editing_app: app, edit_templates: templates, error: nil)}
  end

  def handle_event("close_edit", _params, socket) do
    {:noreply, assign(socket, editing_app: nil, edit_templates: [], error: nil)}
  end

  def handle_event("update", %{"app" => params, "name" => name}, socket) do
    attrs =
      Map.update(params, "default_template_id", nil, fn
        "" -> nil
        v -> v
      end)

    case AppService.update_app(name, attrs) do
      {:ok, _app} ->
        {:noreply,
         assign(socket,
           apps: AppService.list_apps(),
           editing_app: nil,
           edit_templates: [],
           error: nil
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, error: format_errors(changeset))}
    end
  end

  def handle_event("activate", %{"name" => name}, socket) do
    AppService.update_app(name, %{status: :active, verify_date: DateTime.utc_now()})
    {:noreply, assign(socket, apps: AppService.list_apps())}
  end

  def handle_event("deactivate", %{"name" => name}, socket) do
    AppService.update_app(name, %{status: :inactive})
    {:noreply, assign(socket, apps: AppService.list_apps())}
  end

  def handle_event("delete", %{"name" => name}, socket) do
    AppService.delete_app(name)
    {:noreply, assign(socket, apps: AppService.list_apps())}
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
      <h1 class="text-2xl font-bold mb-6">Apps</h1>

      <%= if @error do %>
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm"><%= @error %></div>
      <% end %>

      <%= if @editing_app do %>
        <div class="mb-8 bg-white border border-blue-200 rounded-lg p-4">
          <h2 class="font-semibold mb-3 text-gray-700">Edit — <%= @editing_app.name %></h2>
          <form phx-submit="update">
            <input type="hidden" name="name" value={@editing_app.name} />
            <div class="grid grid-cols-2 gap-3 mb-3">
              <input name="app[domain]" value={@editing_app.domain} placeholder="Domain" required
                class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
              <select name="app[default_template_id]"
                class="border border-gray-300 rounded px-3 py-2 text-sm w-full">
                <option value="">No default template</option>
                <%= for t <- @edit_templates do %>
                  <option value={t.name} selected={t.name == @editing_app.default_template_id}>
                    <%= t.name %>
                  </option>
                <% end %>
              </select>
              <input name="app[default_sender_email]" value={@editing_app.default_sender_email}
                placeholder="Default sender email"
                class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
              <input name="app[default_sender_name]" value={@editing_app.default_sender_name}
                placeholder="Default sender name"
                class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
            </div>
            <div class="flex gap-2">
              <button type="submit"
                class="bg-blue-600 text-white text-sm px-4 py-2 rounded hover:bg-blue-700">
                Save
              </button>
              <button type="button" phx-click="close_edit"
                class="text-sm text-gray-600 border border-gray-300 px-4 py-2 rounded hover:bg-gray-50">
                Cancel
              </button>
            </div>
          </form>
        </div>
      <% else %>
        <form phx-submit="create" class="mb-8 bg-white border border-gray-200 rounded-lg p-4">
          <h2 class="font-semibold mb-3 text-gray-700">New App</h2>
          <div class="grid grid-cols-2 gap-3 mb-3">
            <input name="app[name]" placeholder="Name" required
              class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
            <input name="app[domain]" placeholder="Domain" required
              class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
            <input name="app[default_sender_email]" placeholder="Default sender email"
              class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
            <input name="app[default_sender_name]" placeholder="Default sender name"
              class="border border-gray-300 rounded px-3 py-2 text-sm w-full" />
          </div>
          <button type="submit"
            class="bg-blue-600 text-white text-sm px-4 py-2 rounded hover:bg-blue-700">
            Create
          </button>
        </form>
      <% end %>

      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 border-b border-gray-200">
            <tr>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Name</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Domain</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Status</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Default Sender</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Default Template</th>
              <th class="px-4 py-3"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for app <- @apps do %>
              <tr class={"hover:bg-gray-50 #{if @editing_app && @editing_app.name == app.name, do: "bg-blue-50"}"}>
                <td class="px-4 py-3 font-medium">
                  <a href={~p"/admin/apps/#{app.name}/templates"} class="text-blue-600 hover:underline">
                    <%= app.name %>
                  </a>
                </td>
                <td class="px-4 py-3 text-gray-600"><%= app.domain %></td>
                <td class="px-4 py-3">
                  <span class={"px-2 py-0.5 rounded-full text-xs font-medium #{status_class(app.status)}"}>
                    <%= app.status %>
                  </span>
                </td>
                <td class="px-4 py-3 text-gray-600"><%= app.default_sender_email %></td>
                <td class="px-4 py-3 text-gray-500 text-xs font-mono">
                  <%= app.default_template_id || "—" %>
                </td>
                <td class="px-4 py-3 flex gap-2 justify-end">
                  <button phx-click="open_edit" phx-value-name={app.name}
                    class="text-xs text-gray-600 border border-gray-300 rounded px-2 py-1 hover:bg-gray-50">
                    Edit
                  </button>
                  <%= if app.status != :active do %>
                    <button phx-click="activate" phx-value-name={app.name}
                      class="text-xs text-green-700 border border-green-300 rounded px-2 py-1 hover:bg-green-50">
                      Activate
                    </button>
                  <% else %>
                    <button phx-click="deactivate" phx-value-name={app.name}
                      class="text-xs text-gray-600 border border-gray-300 rounded px-2 py-1 hover:bg-gray-50">
                      Deactivate
                    </button>
                  <% end %>
                  <button phx-click="delete" phx-value-name={app.name}
                    data-confirm={"Delete #{app.name}?"}
                    class="text-xs text-red-600 border border-red-200 rounded px-2 py-1 hover:bg-red-50">
                    Delete
                  </button>
                </td>
              </tr>
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
