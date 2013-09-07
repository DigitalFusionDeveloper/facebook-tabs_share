module GGeocode
### ref: http://code.google.com/apis/maps/documentation/geocoding/

  GGeocode::Version = '0.0.3'

  def GGeocode.version
    GGeocode::Version
  end

  require 'net/http'
  require 'net/https'
  require 'uri'
  require 'cgi'

  begin
    require 'rubygems'
    gem 'multi_json'
    gem 'map'
  rescue LoadError
    nil
  end

  require 'multi_json'
  require 'map'

  AddressPattern = /\w/iox

  def geocode(*args, &block)
    options = Map.options_for!(args)
    if options[:reverse]
      args.push(options)
      return reverse_geocode(*args, &block)
    end
    string = args.join(' ')
    address = address_for(string)
    response = get(geocode_url_for(:address => address))
    result_for(response)
  end

  def reverse_geocode(*args, &block)
    options = Map.options_for!(args)
    string = args.join(' ')
    latlng = latlng_for(string)
    response = get(reverse_geocode_url_for(:latlng => latlng))
    result_for(response)
  end
  alias_method('rgeocode', 'reverse_geocode')

  def timezone(*args, &block)
    options = Map.options_for!(args)
    string = args.join(' ')
    latlng = latlng_for(string)
    timestamp = Time.now.utc.to_i
    response = get(timezone_url_for(:location => latlng, :timestamp => timestamp))
    result_for(response)
  end

  def GGeocode.call(*args, &block)
    options = Map.options_for!(args)
    string = args.join(' ')
    reverse = string !~ AddressPattern || options[:reverse]
    reverse ? GGeocode.reverse_geocode(string) : GGeocode.geocode(string)
  end

  def latlng_for(string)
    lat, lng = string.scan(/[^\s,]+/)
    latlng = [lat, lng].join(',')
  end

  def address_for(string)
    string.to_s.strip
  end

  class StatusError < ::StandardError
    attr_accessor :data
  end

  def result_for(response)
    if response.body.empty?
      raise(StatusError.new)
    end

    hash = MultiJson.decode(response.body)

    map = Map.new
    map.extend(Response)
    map.response = response
    map.update(hash)

    unless hash['status'] == 'OK'
      e = StatusError.new(hash['status'])
      e.data = map
      raise(e)
    end

    map
  end

  module Response
    attr_accessor :response
    def body
      response.body
    end
    alias_method('json', 'body')
  end

  def url_for(which, query = {})
    url = URL_FOR[which].dup 
    url.query = query_for(query)
    url
  end

  URL_FOR = Map.new(
    :geocode =>
      URI.parse("http://maps.google.com/maps/api/geocode/json?"),

    :reverse_geocode =>
      URI.parse("http://maps.google.com/maps/api/geocode/json?"),

    :timezone =>
      URI.parse("https://maps.googleapis.com/maps/api/timezone/json?")
  )

  def geocode_url_for(query = {})
    query[:sensor] = false unless query.has_key?(:sensor)
    GGeocode.url_for(:geocode, query)
  end

  def reverse_geocode_url_for(query = {})
    query[:sensor] = false unless query.has_key?(:sensor)
    GGeocode.url_for(:reverse_geocode, query)
  end

  def timezone_url_for(query = {})
    query[:sensor] = false unless query.has_key?(:sensor)
    GGeocode.url_for(:timezone, query)
  end

  def query_for(options = {})
    pairs = [] 
    options.each do |key, values|
      key = key.to_s
      values = [values].flatten
      values.each do |value|
        value = value.to_s
        if value.empty?
          pairs << [ CGI.escape(key) ]
        else
          pairs << [ CGI.escape(key), CGI.escape(value) ].join('=')
        end
      end
    end
    pairs.replace pairs.sort_by{|pair| pair.size}
    pairs.join('&')
  end

  def get(url)
    uri = url.is_a?(URI) ? URI.parse(url.to_s) : url
    n = 42
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      case uri.scheme
        when 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
    rescue SocketError, TimeoutError
      n -= 1
      return nil if n <= 0
      sleep(rand)
      retry
    end
  end

  extend(GGeocode)
end

module Kernel
private
  def GGeocode(*args, &block)
    GGeocode.call(*args, &block)
  end
end

Ggeocode = GGeocode






if $0 == __FILE__

  require 'pp'

  pp(GGeocode.geocode('boulder, co'))
  pp(GGeocode.rgeocode('40.0149856,-105.2705456'))
  pp(GGeocode.timezone('40.0149856,-105.2705456'))
end





__END__

{"dstOffset"=>0.0,
 "rawOffset"=>-25200.0,
 "status"=>"OK",
 "timeZoneId"=>"America/Denver",
 "timeZoneName"=>"Mountain Standard Time"}

{ 
  "status": "OK",

  "results": [ {
    "types": [ "locality", "political" ],

    "formatted_address": "Boulder, CO, USA",

    "address_components": [ {
      "long_name": "Boulder",
      "short_name": "Boulder",
      "types": [ "locality", "political" ]
    }, {
      "long_name": "Boulder",
      "short_name": "Boulder",
      "types": [ "administrative_area_level_2", "political" ]
    }, {
      "long_name": "Colorado",
      "short_name": "CO",
      "types": [ "administrative_area_level_1", "political" ]
    }, {
      "long_name": "United States",
      "short_name": "US",
      "types": [ "country", "political" ]
    } ],

    "geometry": {
      "location": {
        "lat": 40.0149856,
        "lng": -105.2705456
      },
      "location_type": "APPROXIMATE",
      "viewport": {
        "southwest": {
          "lat": 39.9465862,
          "lng": -105.3986050
        },
        "northeast": {
          "lat": 40.0833165,
          "lng": -105.1424862
        }
      },
      "bounds": {
        "southwest": {
          "lat": 39.9640689,
          "lng": -105.3017580
        },
        "northeast": {
          "lat": 40.0945509,
          "lng": -105.1781970
        }
      }
    }
  } ]
}

