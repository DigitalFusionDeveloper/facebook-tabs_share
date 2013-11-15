class EmailInterceptor
  def self.delivering_email(message)
    App.settings[Rails.env].email_interceptor.each do |method, value|
      message.send(method, value)
    end
  end
end
