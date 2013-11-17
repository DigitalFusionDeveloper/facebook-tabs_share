class EmailAddRecipientsInterceptor
  def self.delivering_email(message)
    App.settings[Rails.env].email_interceptor.each do |method, values|
      next if 'model' == method
      values.each do |value|
        the_value = Array(message.send(method))
        the_value += values
        message.send(method, the_value.flatten.uniq)
      end
    end
  end
end
