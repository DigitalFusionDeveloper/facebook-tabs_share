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

  field :lat, :type => Float
  field :lng, :type => Float
  field :loc, :type => Array

#
  belongs_to(:geo_location, :class_name => '::GeoLocation')
  belongs_to(:map_image, :class_name => '::Upload', inverse_of: nil)

#
  index({:md5 => 1}, {:unique => true})
  index({:state => 1})
  index({:zipcode => 1})
  index({:city => 1})
  index({:loc => '2d'}, {:sparse => true})
  index({:type => 1})

#
  validates_presence_of(:md5)
  validates_presence_of(:raw)
  validates_uniqueness_of(:md5)

#
  before_validation do |location|
    location.md5 = Location.md5_for(location.raw)

    unless location.md5.blank?
      location.md5 = location.md5.force_encoding('utf-8')
    end
  end

#
  def Location.md5_for(raw)
    return nil if raw.blank?
    return nil unless raw.is_a?(Hash)
    Digest::MD5.hexdigest(raw.to_json).to_s.force_encoding('utf-8')
  end

  def Location.[](key)
    any_of( {:_id => key}, {:md5 => key} ).first
  end

#
  def Location.locate_all!(options = {}, &block)
    options.to_options!

    forcing = options[:force]

    if options[:background]
      raise ArgumentError.new('no block allowed with background') if block
      script = Rails.root.join("script/locate_all_locations").to_s
      Thread.new do
        `nohup #{ script.inspect } >> log/locate_all_locations.log 2>&1 &`
      end
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

    2.times do
      query = 
        Location.where(:loc => nil).
          order_by(:brand => :asc, :title => :asc)

      return nil if query.count == 0

      unless options[:client] == false or options[:javascript] == false
        query.each do |location|
          if forcing or GeoLocation.where(:address => location.raw_address).count == 0
            if forcing or not location.javascript_geo_location_job?
              location.create_javascript_geo_location_job
            end
          end
        end
      end

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
    "locations/#{ id }/jobs/geo_location"
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

  def geolocate
    location = self
    geo_location = nil

    address = Location.extract_raw_address(location.raw)

    unless address.blank?
      geo_location = GeoLocation.for(address)

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
          geo_location = GeoLocation.for(zipcode)
        end
      end
    end

    if geo_location
      location.lat = geo_location.lat
      location.lng = geo_location.lng
      location.loc = geo_location.loc

      self.geo_location = geo_location
    else
      false
    end
  end

  def geolocate!
    geolocate
    save!
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
    Location.find_all_by_lat_lng(location.lat, location.lng)
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
    return map_image.s3_url if map_image.try(:s3_url)
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

  # brand, title, street_address, city, state, country, postal_code, type
  #
    def parse
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
