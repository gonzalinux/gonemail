defmodule GonemailWeb.Router do
  use GonemailWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GonemailWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GonemailWeb do
    get "/health", HealthController, :check
  end

  scope "/admin", GonemailWeb do
    pipe_through :browser
    live "/", Live.AdminLive
    live "/apps", Live.AppsLive
    live "/apps/:name/templates", Live.TemplatesLive
    live "/messages", Live.MessagesLive
    live "/send", Live.SendLive
  end

  scope "/api/v1", GonemailWeb do
    pipe_through [:api]

    post "/send", EmailController, :send
    get "/messages/:id", MessageController, :show

    resources "/apps", AppController, except: [:new, :edit] do
      resources "/templates", TemplateController, except: [:new, :edit]
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gonemail, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: GonemailWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
