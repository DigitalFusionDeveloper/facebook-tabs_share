module ExactTarget
  class QueueMO
    require 'exact_target/token_auth'
    include ExactTarget::TokenAuth

    QUEUEMO_URL = 'https://www.exacttargetapis.com/sms/v1/queueMO/'

    def opt_in(phone,keyword = settings.in)
      send_as(phone,keyword)
    end

    def opt_out(phone,keyword = settings.out)
      send_as(phone,keyword)
    end

    def send_as(phone,keyword)
      phone = '1' + phone unless phone =~ /^1/
      response = post_with_auth(QUEUEMO_URL,
                                {'mobileNumbers' => [phone],
                                 'ShortCode' => settings.short_code,
                                 'MessageText' => keyword
                                })
    end

    def self.send_as(phone,message)
      self.new.send_as(phone,message)
    end
  end
end
