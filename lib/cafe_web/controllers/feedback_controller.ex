defmodule CafeWeb.FeedbackController do
  use CafeWeb, :controller
  def index(conn, _params), do: redirect(conn, to: "/?feedback=open")
end
