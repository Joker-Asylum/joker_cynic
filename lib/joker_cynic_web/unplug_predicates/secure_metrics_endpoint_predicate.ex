defmodule JokerCynicWeb.SecureMetricsEndpointPredicate do
  @moduledoc false
  @behaviour Unplug.Predicate

  @impl Unplug.Predicate
  def call(conn, _opts) do
    expected_secret = metrics_token()
    match?([^expected_secret], Plug.Conn.get_req_header(conn, "authorization"))

    true
  end

  defp metrics_token do
    Application.get_env(:joker_cynic, :metrics_auth_token)
  end
end
