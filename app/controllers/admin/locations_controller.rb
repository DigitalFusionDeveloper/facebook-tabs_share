class Admin::LocationsController < Admin::Controller
  include ActionView::Helpers::DateHelper

  def index
    @brands = Brand.all
    query = Location.unscoped.all
    query = search_query_for(query, params)
    locations = query.page(params[:page]).per(10)
    @locations = Conducer.collection_for(locations)
  end

  def import
    brand = params[:importer][:brand] if params[:importer]
    @importer = Location::Importer.new(brand)
    return if request.get?
    unless params[:importer][:file].blank?
      csv = params[:importer][:file].read
      @importer.csv = csv
    end
    @importer.parse
    if @importer.errors.empty?
      @job = Job.submit(Location::Importer,:import_csv!,brand,csv)

      url = url_for(:action => :job, :id => @job.id)

      message.success <<-__
        successful csv parse
        <br>
        check <a href="#{ url }">job #{ @job.id }</a> for progress...
        <br>
        <br>
          Estitmated processing time: #{distance_of_time_in_words(@importer.estimated_time)}
      __
    end
  end

  def job
    @job = Job.find(params[:id])

    if params[:csv] == 'download'
      csv = @job.args.last
      send_data(csv, :filename => "location-#{ @job.created_at.iso8601 }.csv")
      return
    end

    if params[:csv] == 'preview'
      csv = @job.args.last
      render(:text => csv, :content_type => 'text/plain', :layout => false)
      return
    end

    if request.xhr?
      render(:layout => false)
    end
  end
  protected

  def search_query_for(query, params)
    unless params[:search].blank?
      conditions = []
      terms = Array(params[:search]).join(' ').strip.split(/\s+/)
      words = terms.map{|term| "\\b#{ term }\\b"}
      re = /#{ words.join('|') }/i
      conditions = [ {:title => re}, {:slug => re}, {:address => re} ]
      query = query.any_of(conditions)
    else
      query
    end
  end

  class Conducer < App::Conducer
    model_name Location.model_name

    def initialize(location, params = {})
      @location = location

      update_attributes(
        location.to_map
      )

      update_attributes(
        params
      )
    end

    def map_url
      @location.map_url
    end

    def full_address
      @location.full_address
    end

    def save
      raise NotImplementedError
    end
  end
end
