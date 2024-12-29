defmodule JokerCynicBot.Dispatcher do
  @moduledoc false
  use ExGram.Bot,
    name: :joker_cynic,
    setup_commands: true

  alias JokerCynicBot.Reply

  command("privacy", description: "Политика конфиденциальности")

  middleware(JokerCynicBot.Middlewares.SaveUpdateMiddleware)
  middleware(ExGram.Middleware.IgnoreUsername)

  @spec bot() :: :joker_cynic
  def bot, do: :joker_cynic

  @spec handle(ExGram.Dispatcher.parsed_message(), ExGram.Cnt.t()) :: ExGram.Cnt.t()
  def handle(message, context) do
    context
    |> Reply.new(message)
    |> execute_command(message)
    |> Reply.execute()

    context
  end

  defp execute_command(reply, {:command, :privacy, _msg}) do
    JokerCynicBot.PrivacyCommand.call(reply)
  end

  defp execute_command(reply, _msg) do
    %Reply{reply | halt: true}
  end
end
