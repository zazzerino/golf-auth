defmodule GolfWeb.PageController do
  use GolfWeb, :controller

  def home(conn, _params) do
    render(conn, :home, page_title: "Home")
    # The home page is often custom made,
    # so skip the default app layout.
    # render(conn, :home, layout: false)
  end
end
