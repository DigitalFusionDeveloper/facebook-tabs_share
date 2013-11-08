# -*- coding: utf-8 -*-
class Location
##
#

  include App::Document

  default_scope where(active: true)

  name_fields!

  field(:address, :type => String)
  field(:state, :type => String)
  field(:city, :type => String)
  field(:zipcode, :type => String)
  field(:country, :type => String, :default => 'US')
  field(:phone, :type => String)

  field(:type, :type => String)
  field(:active, :type => Boolean, :default => true)

  field(:brand, :type => String)

  field(:raw, :type => Hash, :default => proc{ Hash.new })

  field :lat, :type => Float
  field :lng, :type => Float
  field :loc, :type => Array

  index({:zipcode => 1})
  index({:state => 1})
  index({:city => 1})

  index({:loc => '2d'}, {:sparse => true})
  index({:brand => 1})

  belongs_to(:map_image, :class_name => '::Upload', inverse_of: nil)

  belongs_to(:geo_location, :class_name => '::GeoLocation')

  default_scope order_by(:state => :asc, :city => :asc)

  validates_presence_of(:address)
  validates_presence_of(:state)
  validates_presence_of(:city)
  validates_presence_of(:zipcode)

  def Location.locate_all!(options = {}, &block)
    options.to_options!

    delay =
      if options.has_key?(:delay)
        case options[:delay]
          when false, nil
            0.0
          else
            Float(options[:delay])
        end
      else
        0.200
      end

    42.times do
      query = Location.where(:loc => nil)

      return nil if query.count == 0

      query.each do |location|
        full_address = location.full_address
        next if full_address.blank?
        location.geolocate!
        block.call(location) if block
        sleep(delay) if delay
      end
    end

    return true
  end

  def brand
    Brand.for(read_attribute(:brand))
  end

  def brand=(brand)
    brand = Brand.for(brand)
    write_attribute(:brand, brand ? brand.id : nil)
  end

  def full_address
    [address, city, state, zipcode, country].join(', ')
  end

  def geolocate
    location = self
    geo_location = nil

    if location.loc
      geo_location = GeoLocation.for(location.loc)
    elsif !location.address.blank?
      geo_location = GeoLocation.for(location.full_address)

      legit = proc do |loc|
        (
          !loc.blank? and

          !(is_postal = Array(loc.data.get(:results, 0, :address_components, 0, :types)).include?('postal_code')) and

          !(loc.state.blank? or loc.city.blank?)
        )
      end

      unless legit[geo_location]
        geo_location = GeoLocation.for(location.zipcode)
      end
    end

    if geo_location
      location.lat = geo_location.lat
      location.lng = geo_location.lng
      location.loc = geo_location.loc
      geo_location
    else
      false
    end
  end

  def geolocate!
    geolocate
    save!
  end

  def Location.types
    distinct(:type)
  end

  def Location.geolocate!(options = {})
    options.to_options!
    iterator = options[:thread] ? :threadify : :each
    force = !!options[:force]

    Location.all.send(iterator) do |location|
      location.geolocate! unless(location.geo_location or force)
    end
  end

  def Location.find_all_by_zipcode(zipcode, options = {})
    zipcode = zipcode.to_s.strip.downcase
    options.to_options!

    locations = []

    unless zipcode.blank?
      locations = Location.where('zipcode' => zipcode)

      if locations.blank?
        begin
          ziploc = GeoLocation.for(zipcode)
          lat, lng = ziploc.lat, ziploc.lng
          locations = Location.find_all_by_lng_lat(lng, lat, options)
        rescue Object => e
          raise unless Rails.env.production?
          Rails.logger.error(e)
        end
      end
    end

    locations
  end

# http://stackoverflow.com/questions/5319988/how-is-maxdistance-measured-in-mongodb
#   1° latitude = 69.047 miles = 111.12 kilometers
#

  DEGREES_PER_MILE = 1 / 69.047
  MILES_PER_DEGREE = 1 / DEGREES_PER_MILE

  def Location.find_all_by_lng_lat(lng, lat, options = {})
    options.to_options!

    miles = options[:miles] || 100
    max_distance = miles * DEGREES_PER_MILE

    locations = []

    Location.geo_near([Float(lat),Float(lng)]).max_distance(max_distance).each do |location|
      location['distance'] = Float(location.geo_near_distance) * MILES_PER_DEGREE
      locations.push(location)
    end

    locations
  end

  def Location.find_all_by_lat_lng(lat, lng, options = {})
    Location.find_all_by_lng_lat(lng, lat, options = {})
  end

  def Location.find_all_by_state_and_city(state, city)
    where(:state => /\A#{ state }\Z/i, :city => /\A#{ city }\Z/i)
  end

  def Location.find_all_by_state(state)
    where(:state => /\A#{ state }\Z/i)
  end

  def Location.find_by_string(string)
    begin
      geo = GGeocode.geocode(string)
    rescue GGeocode::Error::Status
      return []
    end
    location = GeoLocation.parse_data(geo)
    Location.find_all_by_lat_lng(location.lat,location.lng)
  end

  def query_string
    query = {
      :center  => "#{ lat },#{ lng }",
      :markers => "color:0x00AEEF|#{ lat },#{ lng }",
      :zoom    => 13,
      :size    => "500x200",
      :scale   => 2,
      :sensor  => false,
      :style   => "saturation:-100"
    }
    query.to_query
  end

  def map_url
    return map_image.s3_url if map_image
    begin
      return image.s3_url if image = cache_map!     
    rescue Object => e
      google_url
    end
    google_url
  end

  def google_url
    url = "http://maps.googleapis.com/maps/api/staticmap?" + query_string
  end

  def map_data(&block)
   open(google_url, 'rb') do |socket|
      block ? block.call(socket) : socket.read
    end
  end

  def cache_map!
    return self.map_image if self.map_image
    if map_data
      filename = Digest::MD5.hexdigest(query_string) + '.png'
      # Already have a map cached for a different brand or past lookup?
      unless self.map_image = Upload.find_by(basename: filename)
        self.map_image = Upload.sio!(map_data, filename: filename)
      end
      self.save!
      self.map_image
    end
  end

  class Importer < ::Dao::Conducer
=begin
The Importer expects rows to be an array of hash like objects that have
at least address, city, state, and zip code. Alternatively, if address looks
like a full address (it contains commas and ends in at least four digits
followed by an optional country) it will be use. "country" and "type" are
opitionally imported.
=end
    require 'csv'

    attr_accessor :rows, :skipped, :brand

    def Importer.import_csv!(brand,csv)
      importer = Importer.new(brand)
      importer.csv = csv
      importer.parse && importer.save
      results = {errors: importer.errors.to_hash, skipped: importer.skipped.to_hash }
    end

    def initialize(brand = '',rows = [])
      @brand = Brand.for(brand)
      @rows = rows
      @imports = []
      @skipped = Map.new
      @cached = 0
    end
      
    def csv=(csv)
      @rows = csv.is_a?(CSV) ? csv : CSV.parse(csv,headers: :first_row, header_converters: :symbol)
    end

    def parse
      @imports = []
      if @brand.blank?
        errors.add(:brand, "is blank")
        return false
      end

      if @rows.empty?
        errors.add(:importer, "No data found")
        return false
      end
      
      @rows.each_with_index do |row, index|
        @row_number = index + 1

        if row.blank?
          @skipped.add("row[#{ @row_number }]", "is blank")
          next
        end

        row[:country] ||= 'US'
        row[:brand] ||= @brand
        row[:organization] ||= @brand.organization
        row[:active] = false

        location = Map(row)
        location[:raw] = location.to_hash

        if valid_address?(location)
          @imports.push(location)
          @cached += 1 if GeoLocation.find_by(address: full_address(location))
        else
          @skipped.add(location.name,location.errors)
        end
      end
      true
    end

    def save
      new_locations = []
      existing_locations = get_existing_locations
      @imports.each do |l|
        # Don't litter the the record with extra fields
        location = Location.new(l.slice(*Location.attribute_names))
        if location.save
          new_locations.push(location.id)
        else
          @errors.add(location.name,location.errors) unless location.save
        end
      end
      # Remove any locations that have been remove from the import.
      Location.unscoped.in(id: existing_locations).destroy_all
      # Activate new locations
      Location.unscoped.in(id: new_locations).update_all(active: true)
      true
    end

    def full_address(location)
      [location[:address], location[:city], location[:state],
       location[:zipcode], location[:country]]
        .delete_if{|_| _.blank?}.join(', ')
    end

    def valid_address?(location)
      if location.address.blank? || 
        ((location.city.blank? || location.state.blank? ||
          location.zipcode.blank?) &&
          # Does the address look like might be a full one
          # Ending in a zip code and optional country?
         !location.address =~ /^.*,.*[-\d]\d{4}(, \w+)?$/)
        location.add(errors, {address: 'Invalid'})
        return false
      else
        return true
      end
    end

    def get_existing_locations
      @existing_locations ||= Location.unscoped.where(brand: @brand.id).map(&:id)
    end

    def estimated_time
      # Figuring 1 second per geo location
      (@imports.count - @cached)
    end
  end
end
