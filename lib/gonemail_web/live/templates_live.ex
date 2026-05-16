defmodule GonemailWeb.Live.TemplatesLive do
  use GonemailWeb, :live_view

  alias Gonemail.Apps.AppService
  alias Gonemail.Templates.{TemplateService, Renderer}

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
           view: :list,
           editing_template: nil,
           error: nil
         )}
    end
  end

  @impl true
  def handle_event("open_new", _params, socket) do
    {:noreply, assign(socket, view: :editor, editing_template: nil, error: nil)}
  end

  def handle_event("open_editor", %{"name" => name}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.name == name))
    {:noreply, assign(socket, view: :editor, editing_template: template, error: nil)}
  end

  def handle_event("close_editor", _params, socket) do
    {:noreply, assign(socket, view: :list, editing_template: nil, error: nil)}
  end

  def handle_event("create", %{"template" => params}, socket) do
    attrs = Map.put(params, "app_id", socket.assigns.app.name)

    case TemplateService.create_template(attrs) do
      {:ok, _template} ->
        {:noreply,
         assign(socket,
           templates: TemplateService.list_templates(socket.assigns.app.name),
           view: :list,
           editing_template: nil,
           error: nil
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, error: format_errors(changeset))}
    end
  end

  def handle_event("edit_save", %{"template" => params, "name" => name}, socket) do
    case TemplateService.update_template(name, params) do
      {:ok, _template} ->
        {:noreply,
         assign(socket,
           templates: TemplateService.list_templates(socket.assigns.app.name),
           view: :list,
           editing_template: nil,
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

  def handle_event("render_preview", %{"html_body" => html, "example_data" => json}, socket) do
    assigns =
      case Jason.decode(json) do
        {:ok, data} when is_map(data) -> %{"data" => data, "body" => data}
        _ -> %{"data" => %{}, "body" => %{}}
      end

    rendered =
      try do
        {_subject, html_body} = Renderer.render(%{subject: "", html_body: html}, assigns)
        html_body
      rescue
        e ->
          "<p style='color:red;font-family:monospace;padding:1rem'>Render error: #{Exception.message(e)}</p>"
      end

    {:noreply, push_event(socket, "preview_rendered", %{html: rendered})}
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
    if assigns.view == :list, do: render_list(assigns), else: render_editor(assigns)
  end

  defp render_list(assigns) do
    ~H"""
    <div>
      <div class="mb-6 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <a href={~p"/admin/apps"} class="text-sm text-gray-500 hover:text-gray-700">← Apps</a>
          <h1 class="text-2xl font-bold"><%= @app.name %> — Templates</h1>
          <span class={"px-2 py-0.5 rounded-full text-xs font-medium #{status_class(@app.status)}"}>
            <%= @app.status %>
          </span>
        </div>
        <button
          phx-click="open_new"
          class="bg-blue-600 text-white text-sm px-4 py-2 rounded hover:bg-blue-700"
        >
          + New Template
        </button>
      </div>

      <%= if @error do %>
        <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm">
          <%= @error %>
        </div>
      <% end %>

      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <%= if @templates == [] do %>
          <div class="px-6 py-12 text-center text-gray-400 text-sm">
            No templates yet. Click "+ New Template" to create one.
          </div>
        <% else %>
          <table class="w-full text-sm">
            <thead class="bg-gray-50 border-b border-gray-200">
              <tr>
                <th class="text-left px-4 py-3 font-medium text-gray-600">Name</th>
                <th class="text-left px-4 py-3 font-medium text-gray-600">Subject</th>
                <th class="text-left px-4 py-3 font-medium text-gray-600">Default Sender</th>
                <th class="px-4 py-3"></th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <%= for template <- @templates do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-4 py-3 font-medium text-gray-900"><%= template.name %></td>
                  <td class="px-4 py-3 text-gray-600"><%= template.subject %></td>
                  <td class="px-4 py-3 text-gray-500 text-xs">
                    <%= if template.default_sender_email do %>
                      <%= template.default_sender_email %>
                      <%= if template.default_sender_name do %>
                        (<%= template.default_sender_name %>)
                      <% end %>
                    <% else %>
                      <span class="italic text-gray-400">app default</span>
                    <% end %>
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex gap-2 justify-end">
                      <button
                        phx-click="open_editor"
                        phx-value-name={template.name}
                        class="text-xs text-gray-600 border border-gray-300 rounded px-3 py-1.5 hover:bg-gray-50"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete"
                        phx-value-name={template.name}
                        data-confirm={"Delete #{template.name}?"}
                        class="text-xs text-red-600 border border-red-200 rounded px-3 py-1.5 hover:bg-red-50"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_editor(assigns) do
    ~H"""
    <div class="flex flex-col" style="height: calc(100vh - 100px)">
      <div class="flex items-center gap-3 mb-4 shrink-0">
        <button type="button" phx-click="close_editor" class="text-sm text-gray-500 hover:text-gray-700">
          ← Templates
        </button>
        <span class="text-gray-300">/</span>
        <h2 class="text-base font-semibold text-gray-800">
          <%= if @editing_template, do: @editing_template.name, else: "New Template" %>
        </h2>
        <div class="ml-auto flex gap-2">
          <button
            type="button"
            phx-click="close_editor"
            class="text-sm text-gray-600 border border-gray-300 px-3 py-1.5 rounded hover:bg-gray-50"
          >
            Cancel
          </button>
          <button
            form="editor-form"
            type="submit"
            class="text-sm bg-blue-600 text-white px-4 py-1.5 rounded hover:bg-blue-700"
          >
            Save
          </button>
        </div>
      </div>

      <%= if @error do %>
        <div class="mb-3 p-3 bg-red-50 border border-red-200 rounded text-red-700 text-sm shrink-0">
          <%= @error %>
        </div>
      <% end %>

      <form
        id="editor-form"
        phx-submit={if @editing_template, do: "edit_save", else: "create"}
        class="flex flex-1 gap-4 overflow-hidden min-h-0"
      >
        <%= if @editing_template do %>
          <input type="hidden" name="name" value={@editing_template.name} />
        <% end %>

        <div class="flex flex-col w-1/2 gap-3 min-h-0">
          <%= if is_nil(@editing_template) do %>
            <input
              name="template[name]"
              placeholder="Template name (e.g. welcome)"
              required
              autocomplete="off"
              class="border border-gray-300 rounded px-3 py-2 text-sm shrink-0"
            />
          <% end %>

          <input
            name="template[subject]"
            value={@editing_template && @editing_template.subject}
            placeholder="Email subject"
            required
            class="border border-gray-300 rounded px-3 py-2 text-sm shrink-0"
          />

          <div class="grid grid-cols-2 gap-3 shrink-0">
            <input
              name="template[default_sender_email]"
              value={@editing_template && @editing_template.default_sender_email}
              placeholder="Sender email (optional)"
              class="border border-gray-300 rounded px-3 py-2 text-sm"
            />
            <input
              name="template[default_sender_name]"
              value={@editing_template && @editing_template.default_sender_name}
              placeholder="Sender name (optional)"
              class="border border-gray-300 rounded px-3 py-2 text-sm"
            />
          </div>

          <div class="flex-1 border border-gray-300 rounded overflow-hidden min-h-0">
            <textarea
              id="html-editor"
              name="template[html_body]"
              required
              phx-hook="Editor"
              data-preview="live-preview"
              data-example-data="example-data"
              data-render-btn="render-btn"
              data-toggle-data-btn="toggle-data-btn"
              data-data-panel="data-panel"
              data-use-data-checkbox="use-data-checkbox"
              class="w-full h-full"
            ><%= @editing_template && @editing_template.html_body %></textarea>
          </div>
        </div>

        <div class="flex flex-col w-1/2 min-h-0 border border-gray-200 rounded overflow-hidden">
          <div class="flex items-center gap-3 px-3 py-1.5 bg-gray-50 border-b border-gray-200 shrink-0">
            <span class="text-xs font-medium text-gray-500">Preview</span>
            <div class="ml-auto flex items-center gap-3">
              <label class="flex items-center gap-1.5 text-xs text-gray-500 cursor-pointer select-none">
                <input
                  type="checkbox"
                  id="use-data-checkbox"
                  class="rounded border-gray-300 text-blue-600"
                />
                Use example data
              </label>
              <button
                id="toggle-data-btn"
                type="button"
                class="text-xs border border-gray-300 rounded px-2 py-0.5 hover:bg-white text-gray-600"
              >
                Data ▾
              </button>
            </div>
          </div>

          <div id="data-panel" class="hidden bg-white border-b border-gray-200 p-3 space-y-2 shrink-0">
            <p class="text-xs text-gray-400">
              JSON — available as
              <code class="bg-gray-100 px-1 rounded font-mono text-gray-600">{"{{ data.key }}"}</code>
              in the template
            </p>
            <textarea
              id="example-data"
              rows="4"
              placeholder={"{ \"name\": \"Alice\", \"code\": \"ABC123\" }"}
              class="w-full border border-gray-300 rounded px-3 py-2 text-xs font-mono resize-none"
            ></textarea>
            <button
              id="render-btn"
              type="button"
              class="text-xs bg-blue-600 text-white rounded px-3 py-1.5 hover:bg-blue-700"
            >
              Render
            </button>
          </div>

          <div class="flex-1 overflow-hidden min-h-0">
            <iframe id="live-preview" sandbox="" class="w-full h-full bg-white"></iframe>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp status_class(:active), do: "bg-green-100 text-green-700"
  defp status_class(:pending), do: "bg-yellow-100 text-yellow-700"
  defp status_class(:inactive), do: "bg-gray-100 text-gray-600"
end
