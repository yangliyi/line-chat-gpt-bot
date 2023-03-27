class LineBotController < ApplicationController
  protect_from_forgery except: [:callback]
  before_action :validate_signature, only: [:callback]

  OPEN_API_ENDPOINT = 'https://api.openai.com/v1/completions'

  def callback
    body = request.body.read
    events = client.parse_events_from(body)

    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          message = event.message['text']
          reply_token = event['replyToken']
          reply_message = chat_gpt_response(message)
          client.reply_message(reply_token, reply_message)
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_ACCESS_TOKEN'] 
    end
  end

  def validate_signature
    signature = request.headers['X-Line-Signature']
    body = request.body.read
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
  end

  def chat_gpt_response(text)
    response = HTTParty.post(OPEN_API_ENDPOINT, 
              headers: {
                "Content-Type" => "application/json",
                "Authorization" => "Bearer #{ENV['CHAT_GPT_API_KEY']}"
              },
              body: {
                "prompt": "#{text}",
                "max_tokens": 1000,
                "temperature": 0.5,
                "model": "text-davinci-003"
              }.to_json
            )

    Rails.logger.info(response)

    message = {
      type: 'text',
      text: response["choices"].first["text"]
    }
    return message
  end

end