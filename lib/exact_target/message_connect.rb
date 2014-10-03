module ExactTarget
  class MessageConnect
    require 'exact_target/token_auth'
    include ExactTarget::TokenAuth

    MESSAGE_CONNECT_URL = 'https://www.exacttargetapis.com/sms/v1/messageContact/'

    def sms(phone,message)
      phone = '1' + phone unless phone =~ /^1/
      url = MESSAGE_CONNECT_URL + settings.template_message_id + '/send'
      response = post_with_auth(url,
                                {'mobileNumbers' => [phone],
                                 'Override'      => true,
                                 'messageText'   => message
                                })
    end

    def deliveries(token)
      url = MESSAGE_CONNECT_URL + settings.template_message_id + '/deliveries/' + token
      response = get_with_auth(url)
    end
  end
end
