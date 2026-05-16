defmodule GonemailWeb.Live.MessagesLive do
  use GonemailWeb, :live_view

  alias Gonemail.Apps.AppService
  alias Gonemail.Messages.MessageService

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       messages: MessageService.list_messages(),
       apps: AppService.list_apps(),
       filter_app: "",
       filter_status: ""
     )}
  end

  @impl true
  def handle_event("filter", %{"app_id" => app_id, "status" => status}, socket) do
    filters =
      []
      |> then(fn f -> if app_id != "", do: Keyword.put(f, :app_id, app_id), else: f end)
      |> then(fn f ->
        if status != "", do: Keyword.put(f, :status, String.to_atom(status)), else: f
      end)

    {:noreply,
     assign(socket,
       messages: MessageService.list_messages(filters),
       filter_app: app_id,
       filter_status: status
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-2xl font-bold mb-6">Messages</h1>

      <form phx-change="filter" class="mb-6 flex gap-3 items-center">
        <select name="app_id" class="border border-gray-300 rounded px-3 py-2 text-sm">
          <option value="">All apps</option>
          <%= for app <- @apps do %>
            <option value={app.name} selected={@filter_app == app.name}><%= app.name %></option>
          <% end %>
        </select>
        <select name="status" class="border border-gray-300 rounded px-3 py-2 text-sm">
          <option value="">All statuses</option>
          <option value="queued" selected={@filter_status == "queued"}>queued</option>
          <option value="retrying" selected={@filter_status == "retrying"}>retrying</option>
          <option value="delivered" selected={@filter_status == "delivered"}>delivered</option>
          <option value="failed" selected={@filter_status == "failed"}>failed</option>
        </select>
      </form>

      <div class="bg-white border border-gray-200 rounded-lg overflow-hidden">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 border-b border-gray-200">
            <tr>
              <th class="text-left px-4 py-3 font-medium text-gray-600">To</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">App</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Template</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Status</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Attempts</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Sent at</th>
              <th class="text-left px-4 py-3 font-medium text-gray-600">Last error</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            <%= for msg <- @messages do %>
              <tr class="hover:bg-gray-50">
                <td class="px-4 py-3">
                  <div class="font-medium"><%= msg.to_email %></div>
                  <%= if msg.to_name do %>
                    <div class="text-xs text-gray-500"><%= msg.to_name %></div>
                  <% end %>
                </td>
                <td class="px-4 py-3 text-gray-600"><%= msg.app_id %></td>
                <td class="px-4 py-3 text-gray-600"><%= msg.template_id %></td>
                <td class="px-4 py-3">
                  <span class={"px-2 py-0.5 rounded-full text-xs font-medium #{status_class(msg.status)}"}>
                    <%= msg.status %>
                  </span>
                </td>
                <td class="px-4 py-3 text-gray-600 text-center"><%= msg.attempts %></td>
                <td class="px-4 py-3 text-gray-500 text-xs">
                  <%= if msg.sent_at, do: Calendar.strftime(msg.sent_at, "%Y-%m-%d %H:%M"), else: "—" %>
                </td>
                <td class="px-4 py-3 text-red-600 text-xs max-w-xs truncate">
                  <%= msg.last_error || "" %>
                </td>
              </tr>
            <% end %>
            <%= if @messages == [] do %>
              <tr>
                <td colspan="7" class="px-4 py-8 text-center text-gray-400 text-sm">No messages found</td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp status_class(:queued), do: "bg-blue-100 text-blue-700"
  defp status_class(:retrying), do: "bg-yellow-100 text-yellow-700"
  defp status_class(:delivered), do: "bg-green-100 text-green-700"
  defp status_class(:failed), do: "bg-red-100 text-red-700"
  defp status_class(_), do: "bg-gray-100 text-gray-600"
end
