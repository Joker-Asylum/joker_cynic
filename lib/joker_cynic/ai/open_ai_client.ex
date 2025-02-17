defmodule JokerCynic.AI.OpenAIClient do
  @moduledoc false
  alias JokerCynic.AI.OpenAIResponse

  @type message :: %{role: String.t(), content: String.t()}

  @spec completion([message()], Keyword.t()) :: {:error, any()} | {:ok, OpenAIResponse.t()}
  def completion(messages, options \\ []) do
    model = Keyword.get(options, :model, "gpt-4o-mini")

    body = %{
      model: model,
      messages: messages
    }

    with {:ok, %{body: body}} <- Tesla.post(client(), "/v1/chat/completions", body) do
      cast_response(body)
    end
  end

  defp cast_response(data) do
    case OpenAIResponse.cast(data) do
      :error -> {:error, :cast_error}
      ok -> ok
    end
  end

  @spec message(String.t(), String.t()) :: message()
  def message(role \\ "user", content) do
    %{role: role, content: content}
  end

  defp api_url do
    :joker_cynic
    |> Application.get_env(__MODULE__)
    |> Keyword.fetch!(:api_url)
  end

  defp api_key do
    token =
      :joker_cynic
      |> Application.get_env(__MODULE__)
      |> Keyword.fetch!(:api_key)

    "Bearer #{token}"
  end

  defp client do
    Tesla.client([
      {Tesla.Middleware.BaseUrl, api_url()},
      {Tesla.Middleware.Headers, [{"authorization", api_key()}]},
      Tesla.Middleware.JSON,
      {Tesla.Middleware.Timeout, timeout: 30_000}
    ])
  end
end
