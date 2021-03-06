class TelegramController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update
    msg = TelegramBotService.new(request).reply_msg
    render plain: true
  end
end
