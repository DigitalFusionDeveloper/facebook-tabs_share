class Admin::LocationsController < Admin::Controller
  include ActionView::Helpers::DateHelper

  before_filter(:setup)

  def index
    @brands    = Brand.all
    query      = @scope.all
    query      = search_query_for(query, params)
    query      = query.order_by(:brand => :asc, :title => :asc)
    locations  = query.page(params[:page]).per(10)
    @locations = Conducer.collection_for(locations)
  end

  def import
    @importer = Location::Importer.new(params[:importer])
    @importer.brand = @brand

    return if request.get?

    if @importer.parse
      @job = @importer.background!

      url = url_for(:action => :job, :id => @job.id)

      message.success <<-__
        successful csv parse
        <br>
        check <a href="#{ url }" target="_blank">job #{ @job.id }</a> for progress...
      __
    end
  end

  def job
    @job = Job.find(params[:id])

    if params[:csv] == 'download'
      csv = @job.args.last['csv']
      send_data(csv, :filename => "locations-#{ @job.created_at.iso8601 }.csv")
      return
    end

    if params[:csv] == 'preview'
      csv = @job.args.last['csv']
      render(:text => csv, :content_type => 'text/plain', :layout => false)
      return
    end

    if request.xhr?
      render(:layout => false)
    end
  end

protected
  def setup
    @brands = Brand.all

    params[:importer] ||= {}

    brand = [params[:importer][:brand], params[:brand_id], params[:brand]].detect{|val| !val.blank?}

    @scope =
      unless brand.blank?
        @brand = Brand.for(brand)
        Location.where(:brand => @brand.slug)
      else
        Location.all
      end

    @scope = @scope.order_by(:organization => :asc, :brand => :asc, :state => :asc, :city => :asc)
  end

  def search_query_for(query, params)
    unless params[:search].blank?
      conditions = []
      terms = Array(params[:search]).join(' ').strip.split(/\s+/)
      words = terms.map{|term| "\\b#{ term }\\b"}
      re = /#{ words.join('|') }/i
      conditions = [ {:title => re}, {:slug => re}, {:address => re}, {:brand => re}, {:md5 => re} ]
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

    def method_missing(method, *args, &block)
      super unless @location.respond_to?(method)
      @location.send(method, *args, &block)
    end

    def save
      raise NotImplementedError
    end
  end
end
