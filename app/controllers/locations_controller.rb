class LocationsController < ApplicationController
  before_filter 'set_brand'

  def index
    @location_string = params[:location_string]
    @zipcode = params[:zipcode]
    @lng = params[:lng]
    @lat = params[:lat]
    @state = params[:state]
    @city = params[:city]
    @types = params[:type]

    location = Location.where(brand: @brand.slug)
    # No types provided is the same as all types

    unless @types.blank?
      location = location.in(type: @types)
    end

    locations =
      case
        when !@location_string.blank?
          location.find_by_string(@location_string)
        when !@zipcode.blank?
          location.find_all_by_zipcode(@zipcode)

        when !@lng.blank? && !@lat.blank?
          location.find_all_by_lng_lat(@lng, @lat)

        when !@state.blank? && !@city.blank?
          location.find_all_by_state_and_city(@state, @city)

        when !@state.blank? && @city.blank?
          location.find_all_by_state(@state).order_by(:city => :asc)

        else
          @needs_pagination = true
          location.all.order_by(:state => :asc,:city => :asc).page(params[:page]).per(25)
      end

      @locations = LocationPresenter.collection_for(locations, params)

      respond_to do |format|
        format.html
        format.json { render :xml => @locations.to_json }
      end
  end

protected
  class LocationPresenter < Dao::Conducer
    def initialize(location, params = {})
      @location = location

      update_attributes(
        Location.new.attributes
      )

      update_attributes(
        location.attributes
      )

      update_attributes(
        :map_url => @location.map_url
      )
    end

    def method_missing(method, *args, &block)
      @location.send(method, *args, &block)
    end

    def address_lines
      address.strip.split(/\s*,\s*/)
    end

    def to_param
      slug
    end
  end
end
