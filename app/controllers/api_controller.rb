# -*- encoding : utf-8 -*-

Kernel.load(File.join(Rails.root, 'lib/api.rb'))

class APIController < ApplicationController

  layout false

  skip_before_filter :verify_authenticity_token

  before_filter :setup_mode
  before_filter :setup_path
  before_filter :setup_api

  WhiteList = Set.new( %w( ping index geolocate) )
  BlackList = Set.new( %w( ) )

  def index

    headers['Access-Control-Allow-Origin']      = '*'
    headers['Access-Control-Allow-Methods']     = 'GET, POST, OPTIONS'
    headers['Access-Control-Max-Age']           = '1728000'
    headers['Access-Control-Allow-Credentials'] = 'true'

    if request.options?
      render(:nothing => true)
      return
    end

    result = call(path, params)
    respond_with(result)

  end

protected

  def call(path, params)
    @result = api.mode(@mode).call(path, params)
  end

  def respond_with(object, options = {})
    json = json_for(object)

    status = object.status rescue (options[:status] || 200)
    status = status.code if status.respond_to?(:code)

    if @format == 'json'
      render(:json => json, :status => status, :callback => params[:callback])
    else
      respond_to do |wants|
        wants.json{ render :json => json, :status => status }
        wants.html{ render :text => json, :status => status, :content_type => 'text/plain' }
        wants.xml{ render :text => 'no soup for you!', :status => 403 }
      end
    end
  end

  if defined?(Rails.stage) and Rails.stage and Rails.stage.production?
    def json_for(object)
      Dao.json_for(object)
    end
  else
    def json_for(object)
      Dao.json_for(object, :pretty => true)
    end
  end

  def setup_path
    @path = params[:path] || params[:action] || 'index'
    @path, @format = @path.split(/\./, 2)
    unless @format.blank?
      params[:format] = @format
      params[:path] = @path
    end
  end


  def setup_mode
    @mode = params['mode'] || request.method.downcase
  end

  def path
    @path
  end

  def mode
    @mode
  end

##
# you'll likely want to customize this for you app as it makes a few
# assumptions about how to find and authenticate users
#
  def setup_api
  #
    @api = Api.new(current_user)

  #
    if white_listed?(path)
      return
    end

  #
    token = params[:token] || request.headers['X-Api-Token'] || request.headers['X-API-TOKEN']

    unless token.blank?
      user = nil
      token = Token.where(:kind => 'api', :uuid => token.to_s).first

      if token and token.context.is_a?(User)
        user = token.context
      end

      if user
        @api.user = user
      else
        render(:nothing => true, :status => :unauthorized)
        return
      end
    else
      email, password = http_basic_auth_info

      if !email.blank? and !password.blank?
        user = User.where(:email => email).first

        if user and user.password == password
          @api.user = user
        else
          headers['WWW-Authenticate'] = ('Basic realm=""' % realm)
          render(:nothing => true, :status => :unauthorized)
          return
        end
      else
        if defined?(current_user) and current_user
          @api.user = current_user
        else
          @api.user = nil
          #headers['WWW-Authenticate'] = ('Basic realm=""' % realm)
          #render(:nothing => true, :status => :unauthorized)
          #return
        end
      end
    end

  #
    unless @api.route?(@path) or @path == 'index'
      render :nothing => true, :status => 404
    end
  end

  def realm
    App.identifier
  end

  def api
    @api
  end

  def self.white_listed?(path)
    WhiteList.include?(path.to_s)
  end

  def white_listed?(path)
    self.class.white_listed?(path)
  end

  def self.black_listed?(path)
    BlackList.include?(path.to_s)
  end

  def black_listed?(path)
    self.class.black_listed?(path)
  end

  def http_basic_auth
    @http_basic_auth ||= (
      request.env['HTTP_AUTHORIZATION']   ||
      request.env['X-HTTP_AUTHORIZATION'] ||
      request.env['X_HTTP_AUTHORIZATION'] ||
      request.env['REDIRECT_X_HTTP_AUTHORIZATION'] ||
      ''
    )
  end

  def http_basic_auth_info
    Base64.decode64(http_basic_auth.to_s.strip.split(/ /).last.to_s).split(/:/, 2)
  end
end

ApiController = APIController ### rails is a bitch - shut her up
