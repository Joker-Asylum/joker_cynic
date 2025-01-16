defmodule JokerCynicBot.AntispamMiddleware do
  @moduledoc false
  use ExGram.Middleware

  import JokerCynicBot.MarkdownUtils

  alias JokerCynic.Antispam
  alias JokerCynicBot.Reply

  @type t :: ExGram.Model.Message.t()

  @spec call(ExGram.Cnt.t(), any()) :: ExGram.Cnt.t()
  def call(context, _options) do
    if context.extra.chat && context.extra.chat.antispam do
      do_call(context)
    else
      context
    end
  end

  defp do_call(context) do
    message = context.update.message
    bot_id = context.bot_info.id

    if left_chat_member = message.left_chat_member do
      clean_bot_messages(left_chat_member, message)
    end

    new_chat_members = Enum.reject(message.new_chat_members || [], &(&1.id == bot_id))

    case new_chat_members do
      [] -> validate_message(context, message)
      _list -> add_captcha(context, message, new_chat_members)
    end
  end

  defp clean_bot_messages(user, message) do
    if captcha = Antispam.get_captcha(user.id, message.chat.id) do
      delete_messages_ids = [captcha.join_message_id, message.message_id | captcha.message_ids]
      ExGram.delete_messages!(captcha.chat_id, delete_messages_ids, bot: bot())
      Antispam.delete_captcha(captcha)
    end
  end

  defp validate_message(context, message) do
    case Antispam.validate_captcha(message.from.id, message.chat.id, message.text) do
      {:ok, nil} ->
        context

      {:ok, captcha} ->
        ExGram.delete_messages!(captcha.chat_id, [message.message_id | captcha.message_ids], bot: bot())
        Antispam.delete_captcha(captcha)

        context
        |> halt()
        |> add_extra(:middleware_reply, %Reply{context: context, text: welcome_message(message.from), markdown: true})

      {:error, captcha} ->
        ExGram.ban_chat_member!(captcha.chat_id, captcha.user_id, bot: bot())
        Antispam.add_message_to_delete(captcha, message.message_id)
        halt(context)
    end
  end

  defp add_captcha(context, message, new_chat_members) do
    questions =
      Enum.map(new_chat_members, fn user ->
        {answer, question} = Antispam.generate_captcha()
        {answer, question, user}
      end)

    user_id = message.from.id
    chat_id = message.chat.id

    on_sent = fn sent_message ->
      Enum.each(questions, fn {answer, _question, _user} ->
        Antispam.assign_captcha(user_id, chat_id, answer, sent_message.message_id, message.message_id)
      end)
    end

    text =
      Enum.map_join(questions, fn {_answer, question, user} ->
        format_question(user, question)
      end)

    context
    |> halt()
    |> add_extra(:middleware_reply, %Reply{context: context, text: text, markdown: true, on_sent: on_sent})
  end

  defp format_question(user, question) do
    ~i"""
    [#{user.first_name}](tg://user?id=#{user.id}), у тебя ровно одна минута, чтобы решить капчу:
    #{question}

    Если ты отправишь что\-то кроме ответа на капчу, я кикну тебя из чата\.
    """
  end

  defp welcome_message(user) do
    ~i"""
    Закуриваю 🚬, выдыхаю дым и с ехидной улыбкой шепчу: “Добро пожаловать в этот цирк, [#{user.first_name}](tg://user?id=#{user.id}), здесь каждый клоун думает, что он главная звезда\.”
    """
  end

  defp bot do
    JokerCynicBot.Dispatcher.bot()
  end
end
