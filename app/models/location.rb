# -*- coding: utf-8 -*-
class Location
#
  include App::Document
  include Brand.able

#
  name_fields!

  field(:md5, :type => String)
  field(:raw, :type => Hash, :default => proc{ Hash.new })
  field(:phone, :type => String)
  field(:type, :type => String)

  field(:street_address, :type => String)
  field(:city, :type => String)
  field(:state, :type => String)
  field(:country, :type => String)
  field(:postal_code, :type => String)

  field :lat, :type => Float
  field :lng, :type => Float
  field :loc, :type => Array

#
  belongs_to(:geo_location, :class_name => '::GeoLocation')
  belongs_to(:map_image, :class_name => '::Upload', inverse_of: nil)

#
  index({:md5 => 1}, {:unique => true})

  index({:street_address => 1})
  index({:city => 1})
  index({:state => 1})
  index({:country => 1})
  index({:postal_code => 1})

  index({:loc => '2d'}, {:sparse => true})

  index({:type => 1})

  index({:geo_location_id => 1})
  index({:map_image_id => 1})

#
  validates_presence_of(:md5)
  validates_presence_of(:raw)
  validates_uniqueness_of(:md5)

#
  before_validation do |location|
    location.generate_md5!
  end

  before_create do |location|
    location.copy_raw_fields!
  end

#
  def Location.md5_for(arg)
    return nil if arg.blank?
    string = arg.is_a?(String) ? arg : arg.to_json
    Digest::MD5.hexdigest(string).to_s.force_encoding('utf-8')
  end

  def Location.[](key)
    any_of( {:_id => key}, {:md5 => key} ).first
  end

  def Location.locate_all!(options = {}, &block)
    options.to_options!

    forcing = options[:force]

    if options[:background]
      raise ArgumentError.new('no block allowed with background') if block
      script = Rails.root.join("script/locate_all_locations").to_s
      Thread.new{ `#{ script.inspect } --daemon` }
      return true
    end

    delay =
      if options.has_key?(:delay)
        case options[:delay]
          when false, nil
            0.0
          else
            Float(options[:delay])
        end
      else
        1.000
      end

  # find un-geolocated locations
  #
    query =
      Location.where(:loc => nil).
        order_by(:brand => :asc, :title => :asc)

  # nothing to do
  #
    return nil if query.count == 0

  # run through all locations using local cache only
  #
    query.each do |location|
      location.geolocate!(:cache => :only) unless location.geo_location
      block.call(location) if block
    end

  # now submit *javascript* jobs for any missing geo_locations
  #
    unless options[:client] == false or options[:javascript] == false
      query.each do |location|
        if forcing or GeoLocation.where(:address => location.raw_address).count == 0
          if forcing or not location.javascript_geo_location_job?
            location.create_javascript_geo_location_job
          end
        end
      end
    end

  # and start doing work in the server - which will eventually BOOM with a
  # OVER_QUERY_LIMIT error ;-(
  #
    unless options[:server] == false or options[:rails] == false
      query.each do |location|
        location.reload

        if forcing or not location.geolocated?
          location.geolocate!
        end

        block.call(location) if block

        sleep(delay) if delay
      end
    end

    return true
  end

  def Location.create_javascript_jobs
    each do |location|
      location.create_javascript_geo_location_job unless
        location.javascript_geo_location_job?
    end
    self
  end

  def build_javascript_geo_location_job(attributes = {})
    code = View.render(:template => 'javascript_jobs/job/geo_location.js.erb', :locals => {:location => self})

    attributes = attributes.to_options!

    attributes[:code] = code
    attributes[:identifier] = javascript_geo_location_job_identifier

    JavascriptJob.new(
      attributes
    )
  end

  def create_javascript_geo_location_job(attributes = {})
    build_javascript_geo_location_job(attributes).tap do |javascript_job|
      javascript_job.save
    end
  end

  def javascript_geo_location_job?
    JavascriptJob.where(:identifier => javascript_geo_location_job_identifier).first
  end

  def javascript_geo_location_job_identifier
    "/locations/#{ id }/jobs/geo_location"
  end

  def Location.extract_raw_address(raw)
    if raw.is_a?(Location)
      raw = raw.raw
    end

    return nil if raw.blank?

    %w( address address1 address2 addr1 addr2 street_address city state postal_code zipcode zip_code country ).map do |field|
      raw[field] || raw[field.to_sym]
    end.select{|cell| not cell.blank?}.join(', ')
  end

  def Location.types
    distinct(:type)
  end

  def geolocated?
    not loc.blank?
  end

  def full_address
    formatted_address || raw_address
  end

  def formatted_address
    geo_location and geo_location.formatted_address
  end

  def raw_address
    Location.extract_raw_address(raw)
  end

  def address
    full_address
  end

  def geolocate(options = {})
    location = self
    geo_location = nil

    address = Location.extract_raw_address(location.raw)

    geo_location_for = proc do |address|
      if options[:cache] == :only
        GeoLocation.where(:address => address).first
      else
        GeoLocation.for(address)
      end
    end

    unless address.blank?
      geo_location = geo_location_for[address]

      if geo_location
        legit = proc do |gloc|
          (
            !gloc.blank? and
            !(is_postal = Array(gloc.data.get(:results, 0, :address_components, 0, :types)).include?('postal_code')) and
            !(gloc.state.blank? or gloc.city.blank?)
          )
        end

        unless legit[geo_location]
          zipcode = %w(zipcode zip_code postal_code).map{|key| location.raw[key]}.detect{|val| !val.blank?}

          if zipcode.blank? and !geo_location.postal_code.blank?
            zipcode = geo_location.postal_code
          end

          unless zipcode.blank?
            geo_location = geo_location_for[zipcode]
          end
        end
      end
    end

    if geo_location
      self.geo_location = geo_location
      location.copy_geolocation_fields!
      geo_location
    else
      false
    end
  end

  def geolocate!(options = {})
    geolocate(options)
    save!
  end

  def copy_geolocation_fields!
    location = self

    if geo_location
      %w(
        street_address city state country postal_code lat lng loc
      ).each do |attr|
        location[attr] = geo_location.send(attr)
      end
    end
  end

  def Location.copy_geolocation_fields!
    Location.all.each do |location|
      location.copy_geolocation_fields!
      location.save!
    end
  end

  def copy_raw_fields!
    location = self

    if raw
      type = raw['type'].to_s
      unless type.blank?
        location.type = Slug.for(type)
      end

      phone = raw['phone'].to_s
      unless phone.blank?
        location['phone'] =
          begin
            digits = phone.scan(/\d/).last(10)
            if digits.size == 10
              digits.unshift('1')
            end
            raise phone.inspect if digits.size < 11
            phone = digits.join
            Phony.formatted(Phony.normalize(phone), :spaces => :-)
          rescue
            nil
          end
      end
    end
  end

  def Location.copy_raw_fields!
    Location.all.each do |location|
      location.copy_raw_fields!
      location.save!
    end
  end


  def generate_md5!
    location = self

    if raw
      location.md5 = Location.md5_for(location.raw)

      unless location.md5.blank?
        location.md5 = location.md5.force_encoding('utf-8')
      end
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

  def Location.find_all_by_lng_lat(*args)
    options = args.extract_options!.to_options!

    lng = args.shift || options[:lng]
    lat = args.shift || options[:lat]

    miles = options[:miles] || 100
    max_distance = miles * DEGREES_PER_MILE

    limit = options[:limit] || 10
    types = options[:types] || options[:type]

    lng = Float(lng)
    lat = Float(lat)

    locations = []

    query = Location.all

    unless limit.blank?
      query = query.limit(limit)
    end

    unless types.blank?
      types = Coerce.list_of_strings(types)
      query = query.where(:type.in => types)
    end

    query.
      geo_near(:lat => lat, :lng => lng).
        max_distance(max_distance).
          each do |location|
            location['distance'] = Float(location.geo_near_distance) * MILES_PER_DEGREE
            locations.push(location)
          end

    geo_locations = GeoLocation.where(:_id.in => locations.map(&:geo_location_id))

    geo_locations.each do |geo_location|
      location = locations.detect{|location| location.geo_location_id == geo_location.id}

      if location
        location.geo_location = geo_location
      end
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

    geo_location = GeoLocation.parse_data(geo)
    Location.find_all_by_lat_lng(geo_location.lat, geo_location.lng)
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
    return nil unless loc

    begin
      Timeout.timeout(1.0) do
        cache_map! unless map_image
        map_image.s3_url || map_image.url
      end
    rescue Object => e
      google_url
    end
  end

  def google_url
    url = "//maps.googleapis.com/maps/api/staticmap?" + query_string
  end

  def map_data(&block)
    open(google_url, 'rb') do |socket|
      block ? block.call(socket) : socket.read
    end
  end

  def cache_map!
    location = self

    if map_image.blank? and not(data = map_data).blank?
      key = map_key
      basename = map_basename

      location.map_image = Upload.find_by(key: key) || Upload.sio!(data, key: key, basename: basename)

      location.save!
    end

    location.map_image
  end

  def map_key
    Location.md5_for(query_string)
  end

  def map_basename
    brand ? "#{ brand.slug }--#{ slug }.png" : "#{ slug }.png"
  end

  class Importer < ::Dao::Conducer
    require 'csv'

    def Importer.import_csv!(*args)
      importer = Importer.new(*args)

      if importer.parse
        result = importer.save
        if result
          importer.html_summary_for(result)
        end
      end
    end

    def initialize(*args)
      options = args.extract_options!.to_options!

      csv   = args.shift || options[:csv] || options[:file]
      brand = args.shift || options[:brand]

      self.csv = csv
      self.brand = brand
    end

    def brands
      @brands ||= Brand.all
    end

    def brand=(brand)
      @brand = Brand.for(brand)
    end

    def brand
      @brand
    end

    def options_for(which)
      case which.to_s
        when /brand/
          brands.map{|brand| [brand.title, brand.slug]}
      end
    end

    def selected_brand
      @brand.try(:slug)
    end

    def csv=(csv)
      case
        when false, nil
          @csv = nil
        when csv.respond_to?(:read)
          @csv = Util.dos2unix(csv.read)
        else
          @csv = Util.dos2unix(csv.to_s)
      end
    end

    def sanitize_csv!
      return unless @csv
      csv = @csv.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')

      clean_csv = [].tap do |lines|
        csv.split("\n").each do |line|
          lines << line.strip.gsub(/,\Z/, '')
        end
      end

      @csv = clean_csv.join("\n")
    end

  # brand, title, street_address, city, state, country, postal_code, type
  #
    def parse
    #
      sanitize_csv!

    #
      @rows = CSV.parse(@csv, headers: :first_row, header_converters: :symbol)

    #
      if @rows.empty?
        errors.add(:importer, "no data in csv")
        return false
      end

    #
      @columns = (@rows.try(:first).try(:headers) || []).map(&:to_s)

    #
      if @brand.blank?
        errors.add("missing 'brand' column") unless @columns.include?('brand')
      end

      unless @columns.include?('title')
        errors.add("missing 'title' column")
      end

      unless %w( address street_address city state country postal_code ).any?{|header| @columns.include?(header)}
        errors.add("no address-like headers found") unless @columns.include?('title')
      end

      return false unless valid?

    #
      @to_import = []

      @rows.each_with_index do |row, index|
        brand =
          if row[:brand].blank?
            @brand
          else
            Brand.for(row[:brand])
          end

        raw = {}

        row.to_hash.each do |key, val|
          key = Slug.for(key).force_encoding('utf-8')
          val = String(val).force_encoding('utf-8')
          raw.update(key => val)
        end

        to_import = {
          'status'     => nil,
          'brand'      => brand.try(:slug),
          'raw'        => raw,
          'location'   => nil,
          'errors'     => nil
        }

        @to_import.push(to_import)
      end

      true
    end

    def save
      @result = []

      brand_location_ids = Hash.new{|hash, brand| hash[brand] = []}

      @to_import.map do |to_import|
      #
        @result.push(to_import)

      #
        brand = to_import['brand']
        raw = to_import['raw']

      #
        to_import['status'] = 'FAILURE'

      #
        brand = Brand.for(brand)

      #
        if brand.blank?
          to_import['errors'] = {'brand' => 'is missing'}
          next
        end

      #
        md5 = Location.md5_for(raw)

        location = Location.where(:md5 => md5).first

        if location
          to_import['status'] = 'SUCCESS'
          to_import['location'] = {'title' => location.title, 'md5' => location.md5}
        else
          attributes = {
            :brand => brand.slug,
            :title => raw['title'],
            :raw   => raw
          }

          location = Location.new(attributes)

          if location.save
            to_import['status'] = 'SUCCESS'
            to_import['location'] = {'title' => location.title, 'md5' => location.md5}
          else
            to_import['status'] = 'FAILURE'
            to_import['errors'] = {}.update(location.errors)
          end
        end

        if location.persisted?
          brand_location_ids[brand].push(location.id)
        end
      end

      brand_location_ids.each do |brand, location_ids|
        brand.locations.where(:_id.nin => location_ids).destroy_all
      end

      Location.locate_all!(:background => true)

      @result
    end

=begin
  {"_rowno":2,"brand":"hacker-pschorr","title":"GINGERMAN","address":"2718  BOLL","city":"DALLAS","state":"TX","country":"75016","zipcode":"Draft","type":""}
=end

    def background!
      Job.submit(Location::Importer, :import_csv!, :csv => @csv, :brand => @brand.try(:slug))
    end

    def html_summary_for(result)
      array = Array(result).flatten.compact
      return nil if array.blank?

      headers = (array.first || {}).keys

      table_(:class => 'table table-striped', :style => 'width:100%;font-size:0.75em;font-family:monospace;'){
        tr_{
          headers.each do |cell|
            td_{ cell }
          end
        }

        array.each do |hash|
          tr_(:style => 'max-width:25%;'){
            hash.each do |key, val|
              if val.is_a?(Hash)
                td_(:style => 'white-space:pre;'){ val.to_yaml.strip }
              else
                td_{ val }
              end
            end
          }
        end
      }
    end
  end
end


__END__
=begin
        _address =
          %w( address street_address city state postal_code zipcode zip_code country ).map do |field|
            row[field] || row[field.to_sym]
          end.select{|cell| not cell.blank?}.join(', ')
=end
