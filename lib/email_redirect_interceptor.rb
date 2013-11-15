class EmailRedirectInterceptor
  def self.delivering_email(message)
    App.settings[Rails.env].email_interceptor.each do |method, values|
      next if 'model' == method
      message.send(method, values)
    end
  end
end
