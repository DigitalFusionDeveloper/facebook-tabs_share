class LocationsController < ApplicationController
  before_filter 'set_brand'

  def index
    @location_string = params[:location_string]
    @zipcode         = params[:zipcode]
    @lng             = params[:lng]
    @lat             = params[:lat]
    @state           = params[:state]
    @city            = params[:city]
    @types           = params[:type]
    @search          = params[:search]

    scope = Location.where(brand: @brand.slug).limit(10)
    # No types provided is the same as all types

    unless @types.blank?
      scope = scope.in(type: @types)
    end

    locations =
      case
        when !@lng.blank? && !@lat.blank?
          scope.find_all_by_lng_lat(@lng, @lat)

        when !@zipcode.blank?
          scope.find_all_by_zipcode(@zipcode)

        when !@state.blank? && !@city.blank?
          scope.find_all_by_state_and_city(@state, @city)

        when !@state.blank? && @city.blank?
          scope.find_all_by_state(@state).order_by(:city => :asc)

        when !@location_string.blank?
          scope.find_by_string(@location_string)

        when !@search.blank?
          @needs_pagination = true
          query = search_query_for(scope, @search).page(params[:page]).per(25)
          locations = query

        else
          @needs_pagination = true
          scope.all.order_by(:state => :asc, :city => :asc).page(params[:page]).per(25)
      end

    if locations.blank? and not @search.blank?
      @needs_pagination = true
      query = search_query_for(scope, @search).page(params[:page]).per(25)
      locations = query
    end

    @locations = LocationPresenter.collection_for(locations, params)
    @points = locations.collect {|l| l.loc}

    respond_to do |format|
      format.html { render template: results_template, layout: false }
      format.json { render :xml => @locations.to_json }
    end
  end

protected

  def search_query_for(query, search = nil)
    unless search.blank? 
      conditions = []
      #terms = Array(search).join(' ').strip.split(/\s+/)
      terms = Array(search).join(' ').strip.scan(/\w+/)
      words = terms.map{|term| "\\b#{ term }\\b"}
      re = /#{ words.join('|') }/i
      conditions = [ {:street_address => re}, {:city => re}, {:state => re}, {:postal_code => re}, {:country => re} ]
      query = query.any_of(conditions)
    else
      query
    end
  end

  def results_template
    File.join('brands', @brand.slug, 'location_results')
    end

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
