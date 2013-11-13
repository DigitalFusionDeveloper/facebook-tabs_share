class ApplicationController < ActionController::Base
  include SslRequirement
#
  protect_from_forgery

#
  before_render do |controller|
    controller.send(:initialize_layout)
  end

#
  layout(:layout_for_request)

# ref: http://broadcastingadam.com/2012/07/advanced_caching_part_7-tips_and_tricks/
#
  def csrf
    authenticated = :you_need_to_implement_this

    csrf =
      {
        "param" => request_forgery_protection_token,
        "token" => form_authenticity_token
      }

    render(:json => (authenticated ? csrf : {}))
  end

# allow non-dynamic pages to access the flash message html
#
  def flash_messages
    if params[:message]
      message params[:message]
    end

    flash_message_keys.each do |key|
      if params[key]
        message.send(key, params[key])
      end
    end

    render(:template => 'shared/flash_messages', :layout => false)
  end

# rpc action support
#
  require 'rpc' unless defined?(RPC)
  include(RPC)

protected
# require ssl for production & staging
#
  def ssl_required?
    (Rails.env.production? or Rails.env.staging?) and Rails.stage
  end

# layout
#
  def initialize_layout
    @layout = LayoutConducer.new

    @layout.nav_for(:main) do |list|
      if current_user and !current_controller.is_a?(AuthController)
        list.link(:home, root_path, :default => true)
      end
    end

    @layout.nav_for(:auth) do |nav|
      if Current.effective_user
        if Current.real_user.su?
          nav.link 'su', su_path, :class => 'su'
        end

        if Current.real_user.su? or Current.real_user.admin?
          nav.link 'admin', admin_path, :class => 'admin'
        end

        options = {}

        if Current.real_user.su?
          options[:title] = "su:#{ Current.real_user.email }"
        end

        nav.link Current.effective_user.email, dashboard_path, options

        nav.link 'logout', helper.logout_path
      else
        nav.link 'login', helper.login_path
        nav.link 'signup', helper.signup_path
      end
    end
  end

# user support
#
  def real_and_effective_users
    @real_and_effective_users ||= (
      hash = {}

      real_user_id = session[:real_user]
      effective_user_id = session[:effective_user]

      real_user_id = nil if real_user_id.blank?
      effective_user_id = nil if effective_user_id.blank?

      if real_user_id and effective_user_id
        users = User.where(:_id.in => [real_user_id, effective_user_id]).to_a
        real_user = users.detect{|u| u.id == real_user_id}
        effective_user = users.detect{|u| u.id == effective_user_id}

        if real_user and effective_user
          hash[:real_user] = real_user
          hash[:effective_user] = effective_user
        end
      end

      if((real_user_id or effective_user_id) and hash.empty?)
        Rails.logger.error("stale session: #{ session.inspect }")
        session.clear
        message('stale or invalid session!', :class => :error)
        redirect_to!('/')
      end

      hash
    )
  end

  def real_user
    @real_user ||= real_and_effective_users[:real_user]
  end
  helper_method(:real_user)

  def effective_user
    @effective_user ||= real_and_effective_users[:effective_user]
  end
  helper_method(:effective_user)

# tracking current state
#
  include Current
  helper{ include Current }

  Current(:real_user){ Current.controller.try(:real_user) }
  Current(:effective_user){ Current.controller.try(:effective_user) }
  Current(:user){ Current.controller.try(:effective_user) }

  def require_current_user
    unless current_user
      message('Please login first', :class => :error)
      redirect_to(login_path)
    end
  end
  alias_method('require_current_user!', 'require_current_user')

  def require_admin_user
    unless(real_user and (real_user.su? or real_user.admin?))
      message("Please login as an admin to view #{ request.url.inspect }", :class => :error)
      return_to!(request.url)
      redirect_to(login_path)
      false
    end
  end
  alias_method('require_admin_user!', 'require_admin_user')

  def require_su_user
    if !real_user 
      flash[:return_to] = request.url
      flash.keep(:return_to)
      message.error("You must first login to access the view you have navigated to.")
      redirect_to(login_path)
    elsif !real_user.su?
      message.error("Sorry, you cannot access #{ request.fullpath }")
      redirect_to("/")
    end
  end
  alias_method('require_su_user!', 'require_su_user')

  def logged_in?
    !session[:real_user].blank? and !session[:effective_user].blank?
  end
  helper_method(:logged_in?)

# sometimes you need an old-skook re-direct
#
  def meta_redirect_to(*args)
    render(:text => meta_refresh_tag(*args))
  end

  def meta_refresh_tag(*args)
    options = args.extract_options!.to_options!
    n = options[:in] || options[:n] || 0
    url = url_for(*args)
    "<meta http-equiv='refresh' content='#{ n };url=#{ CGI.escapeHTML(url) }'>".html_safe
  end
  helper_method('meta_refresh_tag')


# realy return_to in flash
#
  def return_to!(uri)
    flash[:return_to] = uri.to_s
  end

# shortcut
#
  def slash
    root_path
  end
  helper_method(:slash)

# re-define local_request so that it does not lick the hairy ball sack
#
  def local_request?()
    return true if %w( development test ).include?(Rails.env)
    local = %w( 0.0.0.0 127.0.0.1 localhost localhost.localdomain )
    local.include?(request.remote_addr) and local.include?(request.remote_ip)
  end
  helper_method 'local_request?'

# support for layout selection, automatic and manual via params.
#
  def default_layout_for_request
    layout =
      case
        when params[:_layout] || params[:layout]
          l = params[:_layout] || params[:layout]
          l == 'false' ? false : l
        when request.xhr? || params[:xhr]
          false
        else
          default_layout
      end
  end

  def default_layout
    'application'
  end

  def layout_for_request(*layout)
    @layout_for_request ||= default_layout_for_request

    unless layout.empty?
      @layout_for_request = layout.first.to_s 
    end

    @layout_for_request
  end

  def partial?
    (params[:__layout] || params[:layout]) == 'partial'
  end
  helper_method 'partial?'

  def modal?
    (params[:__layout] || params[:layout]) == 'modal'
  end
  helper_method 'modal?'

# encrypt/decrypt support
#
  def encrypt(*args, &block)
    App.encrypt(*args, &block)
  end
  helper_method(:encrypt)

  def decrypt(*args, &block)
    App.decrypt(*args, &block)
  end
  helper_method(:decrypt)

# support for knowing which web server we're running behinde
#
  def ApplicationController.server_software
    @@server_software ||= ENV['SERVER_SOFTWARE']
  end
  def server_software
    ApplicationController.server_software
  end
  helper_method(:server_software)

  def ApplicationController.behind_apache?
    @@behind_apache ||= !!(server_software && server_software =~ /Apache/io)
  end
  def behind_apache?
    ApplicationController.behind_apache?
  end
  helper_method('behind_apache?')

  def ApplicationController.behind_nginx?
    @@behind_nginx ||= !!(server_software && server_software =~ /NGINX/io)
  end
  def behind_nginx?
    ApplicationController.behind_nginx?
  end
  helper_method('behind_nginx?')

# do the 'right thing' when sending files
#
  def x_sendfile(path, options = {})
    if behind_apache? or behind_nginx? or params['x_sendfile']
      headers['X-Sendfile'] = File.expand_path(path)
    end
    send_file(path, options)
  end

  def server_info
    App.server_info
  end
  helper_method :server_info

  def ApplicationController.git_rev()
    App.server_info['git_rev']
  end

  def git_rev
    App.git_rev
  end
  helper_method :git_rev

# various html/form generation shortcuts
#
  def authenticity_token
    @authenticity_token || helper.form_authenticity_token
  end
  helper_method :authenticity_token

  def h(*args, &block)
    args.push(block.call) if block
    Rack::Utils.escape_html(args.join)
  end

  def raw(*args)
    args.join.html_safe
  end

  def helper(*args, &block)
    @helper ||= Helper.new
  end

  def set_brand
    @brand = Brand.for(:slug => params[:brand])

    if @brand.nil?
      render(:text => "brand #{ params[:brand].inspect } not found", :status => 404)
    end
  end

# flash message support
#
  def flash_message_keys
    @flash_keys ||= [:notice, :info, :error, :failure, :warn, :success]
  end
  helper_method(:flash_message_keys)

  def message(*args)
    return messenger if args.empty?

    options = args.extract_options!.to_options!
    message = args.join(' ')

    classes = {
      'notice'  => 'alert',
      'info'    => 'alert alert-info',
      'error'   => 'alert alert-error',
      'failure' => 'alert alert-error',
      'warn'    => 'alert alert-error',
      'success' => 'alert alert-success'
    }

    options[:class] ||= 'notice'
    options[:class] = classes[options[:class].to_s] || options[:class].to_s

    messages.push([message, options])
    messages.uniq!
    message
  end
  helper_method(:message)

  def messages
    messages = (flash['messages'] ||= [])
  end
  helper_method(:messages)

  def messages!
    messages.dup
  ensure
    messages.clear
  end
  helper_method(:messages!)

  def messenger
    @messenger ||= Messenger.new(self)
  end
  helper_method(:messenger)

  class Messenger
    def initialize(controller)
      @controller = controller
    end

    def method_missing(*args, &block)
      options = {:class => args.shift}
      args.push(options)
      @controller.send(:message, *args, &block)
    end
  end
end
