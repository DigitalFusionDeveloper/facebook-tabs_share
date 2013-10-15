class ExactTarget
  class Auth
    def Auth.for(brand)
      config = App.sekrets.exact_target[brand.organization]
      {
        'client' => {
          'id' => config.id,
          'secret' => config.secret
        }
      }
    end
  end
  
  class Client
    @client = {}
    def Client.for(brand)
      @client[brand] ||= FuelSDK::Client.new(Auth.for(brand))
    end
  end

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
    def self.subscribe!(brand,email)
      brand = Brand.for(brand)
      client = Client.for(brand)
      Response.for(client.AddSubscriberToList(email,[brand.triggered_send_key],email))
    end

    def subscribe!(brand,email)
      job = Job.submit(self.class,:subscribe!, brand,email)
    end
  end

  class Send < ExactTarget
    def self.send_email(brand,email)
      brand = Brand.for(brand)
      client = Client.for(brand)
      options = { 'CustomerKey' => brand.triggered_send_key,
        'Subscribers' => { 'EmailAddress' => email,
          'SubscriberKey' => email }
      }
      Response.for(client.SendTriggeredSends([options]))
    end

    def send_email(brand,email)
      job = Job.submit(self.class,:send_email, brand,email)
    end

    def self.send_and_subscribe!(brand,email)
      r = Subscription.subscribe!(brand,email)
      if r.ok?
        r = send_email(brand,email)
      end
      r
    end

    def send_and_subscribe!(brand,email)
      job = Job.submit(self.class,:send_and_subscribe!, brand,email)
    end
  end
end


