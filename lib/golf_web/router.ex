defmodule GolfWeb.Router do
  use GolfWeb, :router

  import GolfWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {GolfWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # scope "/", GolfWeb do
  #   pipe_through :browser

  #   get "/", PageController, :home
  # end

  scope "/", GolfWeb do
    pipe_through :browser

    live_session :home_user,
      on_mount: [{GolfWeb.UserAuth, :mount_current_user}] do
      live "/", HomeLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", GolfWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:golf, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GolfWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GolfWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{GolfWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", GolfWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GolfWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
    end
  end

  scope "/", GolfWeb do
    pipe_through :browser

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{GolfWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/games", GolfWeb do
    pipe_through :browser

    live_session :current_game_user,
      on_mount: [{GolfWeb.UserAuth, :mount_current_user}] do
      live "/:game_id", GameLive
    end
  end

  scope "/games", GolfWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :required_authenticated_game_user,
      on_mount: [{GolfWeb.UserAuth, :ensure_authenticated}] do
      post "/create", GameController, :create_game
    end
  end
end
