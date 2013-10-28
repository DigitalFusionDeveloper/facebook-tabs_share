# -*- coding: utf-8 -*-
class Location
##
#

  include App::Document

  class << self; attr_accessor :geo_delay end

  name_fields!
  field(:address, :type => String)
  field(:state, :type => String)
  field(:city, :type => String)
  field(:zipcode, :type => String)
  field(:country, :type => String, :default => 'US')
  field(:phone, :type => String)

  field(:type, :type => String)
  field(:active, :type => Boolean, :default => true)

  field(:raw, :type => Hash, :default => proc{ Hash.new })

  field :lat, :type => Float
  field :lng, :type => Float
  field :loc, :type => Array

  index({:slug => 1}, {:unique => true })

  index({:zipcode => 1})
  index({:state => 1})
  index({:city => 1})

  index({:loc => '2d'})

  belongs_to(:geo_location, :class_name => '::GeoLocation')

  default_scope order_by(:state => :asc, :city => :asc)

  before_validation do |location|
    location.geolocate
  end


  validates_uniqueness_of(:slug)

  validates_presence_of(:address)
  validates_presence_of(:state)
  validates_presence_of(:city)
  validates_presence_of(:zipcode)
  validates_presence_of(:lat)
  validates_presence_of(:lng)
  validates_presence_of(:loc)

  def full_address
    [address, city, state, zipcode, country].join(', ')
  end

  def geolocate
    location = self

    if location.loc
      geo_location = GeoLocation.for(location.loc,delay: Location.geo_delay)
    elsif !location.address.blank?
      geo_location = GeoLocation.for(location.full_address,delay: Location.geo_delay)

      legit = proc do |loc|
        (
          !loc.blank? and

          !(is_postal = Array(loc.data.get(:results, 0, :address_components, 0, :types)).include?('postal_code')) and

          !(loc.state.blank? or loc.city.blank?)
        )
      end

      unless legit[geo_location]
        geo_location = GeoLocation.for(location.zipcode,delay: Location.geo_delay)
      end

      if geo_location
        location.lat = geo_location.lat
        location.lng = geo_location.lng
        location.loc = geo_location.loc
      end
    end
  end

  def geolocate!
    geolocate
    save!
  end

  def Location.geolocate!(options = {})
    options.to_options!
    iterator = options[:thread] ? :threadify : :each
    force = !!options[:force]

    Location.all.send(iterator) do |location|
      location.geolocate! unless(location.geo_location or force)
    end
  end

  class Importer
=begin
The Importer expects rows to be an array of hash like objects that have
at least address, city, state, and zip code. Alternatively, if address looks
like a full address (it contains commas and ends in at least four digits
followed by an optional country) it will be use. "country" and "type" are
opitionally imported.
=end
    require 'csv'

    attr_accessor :row, :errors, :skipped, :delay

    def initialize(rows = [])
      @rows = rows
      @imports = []
      @errors = Map.new
      @skipped = Map.new
      @delay = (Rails.env.production? ? 1 : 0)
      @cached = 0
    end
      
    def csv=(csv)
      @rows = csv.is_a?(CSV) ? csv : CSV.parse(csv,headers: :first_row, header_converters: :symbol)
    end

    def parse
      @imports = []
      if @rows.empty?
        @errors.add(:importer, "No data found")
        return false
      end
      
      @rows.each_with_index do |row, index|
        @row_number = index + 1

        if row.blank?
          @skipped.add("row[#{ @row_number }]", "is blank")
          next
        end

        row[:country] ||= 'US'

        location = Map(row)
        location[:raw] = row.to_hash

        if valid_address?(location)
          @imports.push(location)
          @cached += 1 if GeoLocation.find_by(address: full_address(location))
        else
          @skipped.add(location.name,location.errors)
        end
      end
    end

    def save
      Location.geo_delay = @delay
      @imports.each do |l|
        location = location_cache.delete(Slug.for(l.name)) || Location.new
        # Don't litter the the record with extra fields
        if !location.update_attributes(l.slice(*Location.attribute_names))
          @errors.add(location.name,location.errors) unless location.save
        end
      end
      # Hide any locations that have been remove from the import.
      Location.in(slug: location_cache.keys).each do |location|
        location.update_attributes!(active: false)
      end
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

    def location_cache
      @location_cache ||= (
        Map.new.tap do |map|
          Location.unscoped.all.each{|location| map[location.slug] = location}
        end
      )
    end

    def estimated_time
      # Figuring 1 second per geo location
      (@imports.count - @cached) * (1 + @delay)
    end
  end
end
