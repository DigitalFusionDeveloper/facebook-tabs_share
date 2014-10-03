module ExactTarget::TokenAuth
  # This module provides a mix in to support getting an access token
  # used by the various ExactTarget APIs.

  TOKEN_URL = 'https://auth.exacttargetapis.com/v1/requestToken'

  def settings
    ExactTarget::Rest.config.settings
  end

  def credentials
    {
      'clientId' => App.sekrets[:exact_target][:client_id],
      'clientSecret' => App.sekrets[:exact_target][:client_secret]
    }
  end

  private
=begin
  def authorize!
    return @access_token if @access_token
    response = post_json(TOKEN_URL,credentials)
    raise unless response.kind_of? Net::HTTPSuccess
    body = MultiJson.load(response.body)
    @access_token = body['accessToken']
  end
=end
  def authorize!
    response = post_json(TOKEN_URL,credentials)
    raise unless response.kind_of? Net::HTTPSuccess
    body = MultiJson.load(response.body)
    @access_token = body['accessToken']
  end

  def post_with_auth(url,data)
    authorize!
    Response.for(post_json(url + "?access_token=#{@access_token}",data))
  end

  def get_with_auth(url)
    authorize!
    p url + "?access_token=#{@access_token}"
    uri = URI(url + "?access_token=#{@access_token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    Response.for(http.get(uri.request_uri))
  end

  def post_json(url,data)
    uri = URI(url)
    http = Net::HTTP.new(uri.host,uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.post(uri.request_uri,
                         MultiJson.dump(data),
                         {'Content-Type' => 'application/json'})
    response
  end

  class Response < ::Map
    def self.for(r)
      status = r.kind_of? Net::HTTPSuccess
      response = super(response: MultiJson.load(r.body),status: status, status_code: r.code).tap do |r|
        r.log!
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
          Rails.logger.info("#{self.class.to_s} !ok? - #{ to_hash.inspect }")
        end
      end
    end
  end
end
