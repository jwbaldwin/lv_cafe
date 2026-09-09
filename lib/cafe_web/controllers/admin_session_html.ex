defmodule CafeWeb.AdminSessionHTML do
  use CafeWeb, :html

  def new(assigns) do
    ~H"""
    <main class="curation-shell curation-login">
      <a href="/">← Back to Vibes</a>
      <h1>Admin sign-in</h1>
      <p :if={!@configured}>Admin access hasn’t been configured yet.</p>
      <p :if={Phoenix.Flash.get(@flash, :error)} role="alert">{Phoenix.Flash.get(@flash, :error)}</p>
      <.form :if={@configured} for={%{}} action="/admin/login">
        <label>Password<input
          name="password"
          type="password"
          autocomplete="current-password"
          required
        /></label>
        <button type="submit">Sign in</button>
      </.form>
    </main>
    """
  end
end
