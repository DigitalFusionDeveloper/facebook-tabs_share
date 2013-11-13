# -*- encoding : utf-8 -*-

class Api < Dao::Api
#
  README <<-__
  __

#
  desc '/ping - hello world without a user'

    call('/ping'){
      data.update :time => Time.now
      errors.add :time, 'fubar'
    }

#
  desc '/pong - hello world with a user'

    call('/pong'){
      require_current_user!
      data.update :time => Time.now
      data.update :current_user => current_user
    }

  desc '/geolocate - geolocate a location'

    call('/geolocate'){
      get {
       if location = GeoLocation.for(params[:location])
         data.update :location => {   city: location.city,
                                     state: location.state,
                                   country: location.country }
       end
      }
    }

  desc '/jobs/next - get the next job to run'
    call('/jobs/next'){
      get {
        stale = Time.now - (Rails.env.development? ? 0 : 60)

        job = JavascriptJob.next!(:stale => stale)

        data.update(
          'job' => job.try(:to_map)
        )
      }
    }

  desc '/jobs/:id - get or put job data'
    call('/jobs/:id'){
      get {
        job = JavascriptJob.find(params[:id])

        data.update(
          'job' => job.try(:to_map)
        )
      }

      put {
        job = JavascriptJob.find(params[:id])

        if params[:job]
          job.result = params[:job][:result]
          job.completed!
        end

        data.update(
          'job' => job.to_map
        )
      }
    }

  desc '/geo_locations - post new geolocations'
    call('/geo_locations'){
      post{
        address  = params['address']
        data     = params['data']

        geo_location = GeoLocation.find_by(:address => address)

        unless geo_location
          geo_location = GeoLocation.from_javascript(:data => data, :address => address)

          unless geo_location.save
            geo_location = GeoLocation.find_by(:address => address)
          end
        end

        data.update('geo_location' => geo_location.try(:id))
      }
    }

#
  attr_accessor :effective_user
  attr_accessor :real_user

  def initialize(*args)
    options = args.extract_options!.to_options!
    effective_user = args.shift || options[:effective_user] || options[:user]
    real_user = args.shift || options[:real_user] || effective_user
    @effective_user = user_for(effective_user) unless effective_user.blank?
    @real_user = user_for(real_user) unless real_user.blank?
    @real_user ||= @effective_user
  end

#
  def user_for(arg)
    return nil if arg.blank?
    User[arg]
  end

  alias_method('user', 'effective_user')
  alias_method('user=', 'effective_user=')
  alias_method('current_user', 'effective_user')
  alias_method('current_user=', 'effective_user=')
  alias_method('effective_user?', 'effective_user')
  alias_method('real_user?', 'real_user')

  def api
    self
  end

  def logged_in?
    @effective_user and @real_user
  end

  def user?
    logged_in?
  end

  def user
    effective_user
  end

  def user=(user)
    @effective_user = @real_user = user_for(user)
  end

  def current_user
    effective_user
  end

  def current_user?
    !!effective_user
  end

  def require_effective_user!
    unless effective_user?
      status :unauthorized
      return!
    end
  end

  def require_real_user!
    unless real_user?
      status :unauthorized
      return!
    end
  end

  def require_current_user!
    require_effective_user! and require_real_user!
  end
  alias_method('require_user!', 'require_current_user!')


  PER_PAGE = 1024

  def paginate(results)
    per_page = Integer(params[:per] || params[:per_page] || PER_PAGE)
    results.page(params[:page]).per(per_page)
  end

  def pagination_links_for(*args, &block)
    Api.pagination_links_for(endpoint.path, *args, &block)
  end

  def headers(hash = {})
    headers = current_controller.headers
    hash.each{|k, v| headers[k.to_s] = v.to_s}
    headers
  end

  class << Api
    def pagination_links_for(endpoint, page)
      current_page = page.current_page
      num_pages = page.num_pages

      links = []

      unless current_page >= num_pages
        next_page = current_page += 1
        links.push(:rel => 'next', :url => Api.url(endpoint, :page => next_page))
      end

      last_page = num_pages

      links.push(:rel => 'last', :url => Api.url(endpoint, :page => last_page))

      links.map do |link|
        '<%s>; rel="%s"' % [link[:url], link[:rel]]
      end.join(', ')
    end

    def root(options = {})
      options = options.to_options!

      protocol = options.has_key?(:protocol) ? options[:protocol] : Api.protocol
      host = options.has_key?(:host) ? options[:host] : Api.host
      port = options.has_key?(:port) ? options[:port] : Api.port

      root = []

      if protocol and host
        protocol = protocol.to_s.split(/:/, 2).first 
        root << protocol
        root << "://#{ host }"
      else
        root << "//#{ host }"
      end

      if port
        root << ":#{ port }"
      end

      root.join
    end

    def route
      '/v1'
    end

    def url(*args)
      options = args.extract_options!.to_options!

      only_path    = options.delete(:only_path)
      path_info    = options.delete(:path_info) || options.delete(:path)
      query_string = options.delete(:query_string)
      fragment     = options.delete(:fragment) || options.delete(:hash)
      query        = options.delete(:query) || options.delete(:params)

      raise(ArgumentError, 'both of query and query_string') if query and query_string

      args.push(path_info) if path_info

      url = ('/' + args.join('/')).gsub(%r|/+|,'/')

      unless only_path
        root = Api.root(options).sub(%r|/*$|,'')
        url = root + route + url
      end

      if query.blank?
        query = options
      end

      url += ('?' + query_string) unless query_string.blank?
      url += ('?' + query.query_string) unless query.blank?
      url += ('#' + fragment) if fragment
      url
    end

    %w( protocol host port ).each do |attr|
      eval <<-__
        def #{ attr }
          unless defined?(@#{ attr })
            @#{ attr } = DefaultUrlOptions.#{ attr }
          end

          @#{ attr }
        end

        def #{ attr }=(value)
          @#{ attr } = value
        end
      __
    end

    def domain
      @domain || (
        case host
          when '0.0.0.0'
            'localhost'
          when /\A[\d.]+\Z/iomx
            host
          else
            host.split('.').last(2).join('.')
        end
      )
    end

    def domain=(value)
      @domain = value
    end
  end
end

API = Api
