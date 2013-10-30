class GeoLocation
##
#
  include App::Document

##
#
  field :address
  field :formatted_address
  field :country
  field :administrative_area_level_1
  field :administrative_area_level_2
  field :administrative_area_level_3
  field :locality
  field :sublocality
  field :prefix
  field :postal_code

  field :results_index, :type => Integer

  field :lat, :type => Float 
  field :lng, :type => Float
  field :loc, :type => Array
  field :utc_offset, :type => Float
  field :timezone_id


  field :data, :type => App::Document::Type::Map, :default => proc { Map.new }

##
#
  validates_uniqueness_of :address

  validates_presence_of :address
  validates_presence_of :prefix
  validates_presence_of :address
  validates_presence_of :country
  validates_presence_of :lat
  validates_presence_of :lng

##
#
  index({:address => 1}, :unique => true)
  index({:prefix => 1})
  index({:country => 1})
  index({:administrative_area_level_1 => 1})
  index({:administrative_area_level_2 => 1})
  index({:locality => 1})
  index({:sublocality => 1})
  index({:postal_code => 1})
  index({:lat => 1})
  index({:lng => 1})
  index({:loc => '2d'})

##
#
  before_validation(:on => :create) do |location|
    location.loc = [location.lat, location.lng]
  end

  after_save(:on => :create) do |location|
    #location.ensure_parents_exist!
  end

##
#
  validate(:validate!)

  def validate!
    if address and data.blank?
      errors.add(:address, "#{ address.inspect } not found") 
    end

    if data and pinpoint?
      unless results_index
        formatted_addresses = GeoLocation.formatted_addresses_for(data)

        if formatted_addresses.uniq.size > 1
          message = "ambiguous location: " + formatted_addresses.join(' | ')
          errors.add(:address, message)
        end
      end
    end
  end

##
#
  fattr(:pinpoint){ false }

##
#
  def GeoLocation.locate(address, options = {})
  #
    options.to_options!
    pinpoint = !!options[:pinpoint]

  #
    location = GeoLocation.where(:address => address).first
    if location
      location.pinpoint = pinpoint
      return location
    end

  #
    location = GeoLocation.new(:address => address)
    location.pinpoint = pinpoint

    if options[:data]
      location.data = Map.for(options[:data])
    else
      location.data = GGeocode.geocode(address)
      if options[:delay]
        sleep(options[:delay].to_i + rand)
      end
    end

    if options[:results_index]
      location.results_index = Integer(options[:results_index])
    end

    if location.data
      attributes =
        GeoLocation.parse_data(location.data, :results_index => location.results_index) || Map.new

      location.attributes.update(attributes)

      location.calculate_timezone!
    end

  #
    location.save
    location
  end

  class Error < ::StandardError; end

  def GeoLocation.locate!(*args, &block)
    location = GeoLocation.locate(*args, &block)

    if location.blank? or not location.valid?
      message = location ? location.errors.inspect : ''
      raise Error.new(message)
    end

    location
  end

  def GeoLocation.for(*args, &block)
    location = GeoLocation.locate!(*args, &block)
  rescue
    nil
  end

  def GeoLocation.pinpoint(string)
    data = GGeocode.geocode(string)
    list = GeoLocation.formatted_addresses_for(data)
    list.size == 1 ? list.first : false
  end

  def GeoLocation.pinpoint?(string)
    GeoLocation.pinpoint(string)
  end

  def GeoLocation.geocode(string)
    GGeocode.geocode(string)
  end

  def GeoLocation.reverse_geocode(string)
    GGeocode.reverse_geocode(srting)
  end

  def GeoLocation.rgeocode(string)
    GGeocode.reocode(srting)
  end

  def GeoLocation.parse_data(data, options = {})
    options.to_options!
    data = Map.for(data)
    parsed = Map.new

    results = data['results']
    return nil unless results

    result = results[options[:results_index] || 0]
    return nil unless result

    address_components = result['address_components']
    return nil unless address_components

    geometry = result['geometry']
    return nil unless geometry 

    location = geometry['location']
    return nil unless location 

    component_for = lambda{|target| address_components.detect{|component| (component['types'] & target).sort == target.sort}}
    [
      %w( political country ),
      %w( political administrative_area_level_1 ),
      %w( political administrative_area_level_2 ),
      %w( political administrative_area_level_3 ),
      %w( political locality ),
      %w( political sublocality ),
      %w( postal_code ),
    ].each do |target|
      component = component_for[target]
      next unless component
      long_name = component['long_name']
      next unless long_name
      key = target.last
      parsed[key] = long_name
    end

    prefix =
      absolute_path_for(
        parsed['country'],
        parsed['administrative_area_level_1'],
        parsed['administrative_area_level_2'],
        parsed['locality']
      )

    parsed['prefix'] = prefix
    parsed['formatted_address'] = result['formatted_address']
    parsed['lat'] = location['lat']
    parsed['lng'] = location['lng']

    return nil if parsed.empty?
    parsed
  end

  def GeoLocation.formatted_addresses_for(data)
    return [] unless data
    results = data['results']
    return [] unless results
    results.map{|result| result['formatted_address']}.uniq
  end

  def GeoLocation.absolute_path_for(*args)
    return '/' if args.empty?
    args = Util.absolute_path_for(*args).split('/')
    args.map!{|arg| Slug.for(arg)}
    Util.absolute_path_for(*args)
  end

  def GeoLocation.prefixes
    GeoLocation.all.order(:prefix).distinct(:prefix)
  end

  def GeoLocation.list
    items = {}
    prefixes.each do |prefix|
      loop do
        items[prefix] ||= prefix
        prefix = File.dirname(prefix)
        break if prefix=='/'
      end
    end
    items.keys.sort
  end

  def GeoLocation.prefixes_for(prefix)
    prefixes = []
    prefix = GeoLocation.absolute_path_for(prefix)
    loop do
      prefixes.unshift(prefix)
      prefix = File.dirname(prefix)
      break if prefix=='/'
    end
    prefixes
  end


# FIXME - this doesn't *quite* work, for example 'denver, co'
#
  def GeoLocation.ensure_parents_exist!(location)
    prefix = location.prefix
    parts = [location.country, location.administrative_area_level_1, location.administrative_area_level_2, location.locality].compact
    parts.pop

    locations = []

    until parts.empty?
      address = parts.join(', ')
      parts.pop
      location = GeoLocation.locate(address)
      break unless(location and location.valid?)
      next unless prefix.index(location.prefix) == 0
      location.save! if location.new_record?
      locations.push(location)
    end

    locations
  end

  def ensure_parents_exist!
    GeoLocation.ensure_parents_exist!(location=self)
  end


  def GeoLocation.default
    @default ||= GeoLocation.where('prefix' => '/united-states').first
  end

  scope(:prefixed_by,
    lambda do |prefix|
      prefix = GeoLocation.absolute_path_for(prefix)
      where(:prefix => /^#{ prefix }/)
    end
  )

  def GeoLocation.prefix?(prefix)
    prefix = GeoLocation.absolute_path_for(prefix)
    where(:prefix => /^#{ prefix }/).count != 0
  end

  def to_s
    prefix
  end

  def basename
    File.basename(prefix)
  end

  def latlng
    [lat, lng].join(',').gsub(/\s+/, '')
  end
  alias_method(:ll, :latlng)
  alias_method(:lon, :lng)

  def state
    administrative_area_level_1
  end

  def city
    locality || sublocality || administrative_area_level_3
  end

  def same
    GeoLocation.new(
      :lat     => lat,
      :lng     => lng,
      :prefix  => prefix,
      :address => address,
      :data    => data
    )
  end

  def calculate_timezone!
    data = GGeocode.timezone(lat, lng)
    self.utc_offset = data["rawOffset"]
    self.timezone_id = data["timeZoneId"]
  end

  def time_zone(&block)
    if block
      Time.use_zone(time_zone){ block.call(time_zone) }
    else
      @time_zone ||= ActiveSupport::TimeZone[ timezone_id || utc_offset ]
    end
  end
  alias_method(:timezone, :time_zone)

  def time
    Time.use_zone( time_zone ) do
      Time.zone.now
    end
  end
  alias_method('now', 'time')

  def time_for(t)
    t =
      case t
        when Time, Date
          t.to_time.to_s
        else
          t.to_s
      end
    time_zone.parse(t.to_s)
  end

  def date_for(d)
    time_for(d).to_date
  end

  def date
    date_for(Date.today)
  end

  def GeoLocation.date_range_for(location, date_range_name)
    today = Date.today
    date_a = nil
    date_b = nil
    name = nil

    case date_range_name.to_s
      when 'today'
        name = 'today'
        date_a = location.time_for(today)
        date_b = date_a + 24.hours
      when 'tomorrow'
        name = 'tomorrow'
        date_a = location.time_for(today + 1)
        date_b = date_a + 24.hours
      when 'this_weekend', 'weekend'
        name = 'this_weekend'
        day = location.time_for(today)
        until day.strftime('%a') == 'Sat'
          day += 1.day
        end
        date_a = location.time_for(day)
        date_b = date_a + 2.days
      when 'this_week', 'week'
        name = 'this_week'
        date_a = location.time_for(today)
        date_b = date_a + 1.week
      when 'this_month', 'month'
        name = 'this_month'
        date_a = location.time_for(today)
        date_b = date_a + 1.month
      when 'this_year', 'year'
        name = 'this_year'
        date_a = location.time_for(today)
        date_b = date_a + 1.year
      when 'all'
        name = 'all'
        date_a = Time.starts_at
        date_b = Time.ends_at
    end

    DateRange.new(date_a, date_b, name)
  end

  def date_range_for(date_range_name)
    GeoLocation.date_range_for(location=self, date_range_name)
  end

  def GeoLocation.date_range_name_for(location, date)
    ranges = %w( today tomorrow this_weekend this_week this_month this_year all ).map{|name| date_range_for(location, name)}
    time = date.to_time
    range = ranges.detect{|r| r.include?(time)}
    range.name
  end

  def date_range_name_for(date)
    GeoLocation.date_range_name_for(location=self, date)
  end

  class DateRange < ::Range
    attr_accessor :name

    def initialize(a, b, name)
      a ||= Time.starts_at
      b ||= Time.ends_at
      name ||= 'All'
      super(a, b)
      self.name = Slug.for(name)
    end
  end


=begin
  http://www.earthtools.org/timezone/40.71417/-74.00639

  Time.parse('2011-02-12 17:28:10Z') - Time.parse('2011-02-12 22:28:10Z') #=> -18000.0

  def utc_offset
    -18000
  end
=end
end
