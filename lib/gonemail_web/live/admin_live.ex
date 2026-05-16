defmodule GonemailWeb.Live.AdminLive do
  use GonemailWeb, :live_view

  alias Gonemail.Apps.AppService
  alias Gonemail.Messages.MessageService

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       app_count: length(AppService.list_apps()),
       pending_count: MessageService.count_pending()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl">
      <h1 class="text-2xl font-bold mb-2">Gonemail</h1>
      <p class="text-gray-500 text-sm mb-8">Self-hosted transactional email service</p>

      <div class="grid grid-cols-2 gap-4 mb-8">
        <div class="bg-white border border-gray-200 rounded-lg p-4">
          <div class="text-2xl font-bold text-gray-800"><%= @app_count %></div>
          <div class="text-sm text-gray-500">Registered apps</div>
        </div>
        <div class="bg-white border border-gray-200 rounded-lg p-4">
          <div class="text-2xl font-bold text-gray-800"><%= @pending_count %></div>
          <div class="text-sm text-gray-500">Pending messages</div>
        </div>
      </div>

      <div class="grid grid-cols-1 gap-3">
        <a href={~p"/admin/apps"}
          class="bg-white border border-gray-200 rounded-lg p-4 flex items-center gap-4 hover:border-blue-300 hover:bg-blue-50 transition-colors">
          <div class="flex-1">
            <div class="font-medium text-gray-800">Apps</div>
            <div class="text-sm text-gray-500">Manage registered apps and domain verification — click an app name to edit its templates</div>
          </div>
          <span class="text-gray-400">→</span>
        </a>
        <a href={~p"/admin/messages"}
          class="bg-white border border-gray-200 rounded-lg p-4 flex items-center gap-4 hover:border-blue-300 hover:bg-blue-50 transition-colors">
          <div class="flex-1">
            <div class="font-medium text-gray-800">Messages</div>
            <div class="text-sm text-gray-500">Delivery log with status and app filters</div>
          </div>
          <span class="text-gray-400">→</span>
        </a>
        <a href={~p"/admin/send"}
          class="bg-white border border-gray-200 rounded-lg p-4 flex items-center gap-4 hover:border-blue-300 hover:bg-blue-50 transition-colors">
          <div class="flex-1">
            <div class="font-medium text-gray-800">Send Test</div>
            <div class="text-sm text-gray-500">Send a test email using any active app and template</div>
          </div>
          <span class="text-gray-400">→</span>
        </a>
      </div>
    </div>
    """
  end
end
