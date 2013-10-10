class ExactTarget
  def self.config
    @config ||= App.sekrets.exact_target
  end

  def self.auth
    {
      'client' => {
        'id' => config.id,
        'secret' => config.secret
      }
    }
  end

  def self.client
      @client ||= FuelSDK::Client.new(auth)
  end

  def client
    @client ||= self.class.client
  end

  # TODO - These should return something reasonable


  class Response < ::Map
    def self.for(r)
      response = super(:response => r.results.first, :status => r.status).tap do |response|
        response.log!
      end
    end

    def success?(&block)
      block && status ? block.call : status
    end

    def ok?(&block)
      success?(&block)
    end


    def log!
      unless success?
        begin
          Log::ExactTarget.log!(response=self)
        rescue
          Rails.logger.info("SmartButton !ok? - #{ to_hash.inspect }")
        end
      end
    end
  end
  
  class Subscription < ExactTarget
    def self.template
      config.template
    end

    def self.subscribe!(email)
      Response.for(client.AddSubscriberToList(email,[config.list_id],email))
    end

    def subscribe!(email)
      job = Job.submit(self.class,:subscribe!, email)
    end
  end

  class Send < ExactTarget
    def self.send_email(template,email)
      options = { 'CustomerKey' => template,
        'Subscribers' => { 'EmailAddress' => email,
          'SubscriberKey' => email }
      }
      Response.for(client.SendTriggeredSends([options]))
    end

    def send_email(template,email)
      job = Job.submit(self.class,:send_email, template,email)
    end

    def self.send_and_subscribe!(template,email)
      r = Subscription.subscribe!(email)
      if r.ok?
        r = send_email(template,email)
      end
      r
    end

    def send_and_subscribe!(template,email)
      job = Job.submit(self.class,:send_and_subscribe!, template,email)
    end
  end
end


