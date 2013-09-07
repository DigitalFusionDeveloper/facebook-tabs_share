class Admin::UsersController < Admin::Controller
  def index
    query = User.order_by(:email => :asc)
    query = search_query_for(query, params)
    users = query.page(params[:page]).per(10)
    @users = Conducer.collection_for(users)
  end

  def edit
    user = User.find(params[:id])
    @user = Conducer.for(user, params[:user])
  end

  def update
    user = User.find(params[:id])
    @user = Conducer.for(user, params[:user])

    if @user.save
      message "User #{ @user.email.inspect } saved", :class => :success
      redirect_to :action => :show, :id => @user.id
    else
      message "Failed to save #{ @user.email.inspect }", :class => :failure
    end
  end

  def new
    user = User.new
    @user = Conducer.for(user, params[:user])
  end

  def create
    user = User.new
    @user = Conducer.for(user, params[:user])

    if @user.save
      message "User #{ @user.email.inspect } created", :class => :success
      redirect_to :action => :show, :id => @user.id
    else
      message "Failed to create user", :class => :failure
      render :action => :edit
    end
  end

  def show
    user = User.find(params[:id])

    if params[:login]
      session[:effective_user] = user.id
      redirect_to(params[:login])
      message "Logged in as #{ user.email.inspect }", :class => :success
      return
    end

    @user = Conducer.for(user, params[:user])
  end

  def welcome
    user = User.find(params[:id])
    @user = Conducer.for(user, params[:user])

    return if request.get?

    if @user.welcome
      message("User #{ @user.email.inspect } welcomed!", :class => :success)
      redirect_to(:action => :edit, :id => @user.id)
    else
      message("Failed to welcome #{ @user.email.inspect }", :class => :failure)
    end
  end

protected
  def search_query_for(query, params)
    unless params[:search].blank?
      conditions = []
      terms = Array(params[:search]).join(' ').strip.split(/\s+/)
      words = terms.map{|term| "\\b#{ term }\\b"}
      re = /#{ words.join('|') }/i 
      conditions = [ {:email => re}, {:first_name => re}, {:last_name => re} ]
      query = query.any_of(conditions)
    else
      query
    end
  end

  class Conducer < App::Conducer
    model_name User.model_name

    def initialize(user, params = {})
    # user attributs
    #
      @user = user

      update_attributes(
        user_attributes_for(@user)
      )

    # overlay params
    #
      update_attributes(
        params
      )

    # *never* show password
    #
      @password = attributes.delete(:password)
    end

    def user_attributes_for(user)
      user.to_map.tap do |attributes|
        attributes[:logged_in_at] = nil unless attributes.has_key?(:logged_in_at)
        attributes[:roles] = role_map_for(@user)
      end
    end

    def role_map_for(user)
      User.roles.inject({}){|h, r|  h.update(r => user.has_role?(r))}
    end

    def readonly_role?(role)
      role = role.to_s.strip.downcase

      if current_user == @user
      # you cannot un-admin yourself
      #
        if current_user.roles.include?('admin') and role == 'admin'
          return true
        end

      # you cannot un-su yourself
      #
        if current_user.roles.include?('su') and role == 'su'
          return true
        end
      end

      # you cannot un-su someone if you are not an su
      #
        if not current_user.roles.include?('su') and role == 'su'
          return true
        end

      return false
    end

    def list_of_roles
      @user.roles.dup
    end

    def save
    # attrs
    #
      %w(
        email first_name last_name
      ).each do |attr|
        value = attributes.get(attr)
        @user.send("#{ attr }=", value)
      end

    # password
    #
      unless @password.blank?
        @user.password = @password
      end

    # roles
    #
      params.roles.each do |role, has_role|
        Coerce.boolean(has_role) ? @user.add_role(role) : @user.remove_role(role)
      end

    # save
    #
      if @user.save
        true
      else
        errors.relay(@user.errors)
        false
      end
    end

    def session
      @user.session
    end

    def logged_in
      if attributes[:logged_in_at]
        helper.time_ago_in_words(attributes.logged_in_at) + ' ago'
      else
        'never'
      end
    end

    def welcome
      begin
        Mailer.welcome(@user.email, subject, message).deliver
      rescue
        errors.add("Sorry, sending failed - try again later.")
        return false
      end

      return true
    end

    def welcome_message
      build_welcome_message unless defined?(@welcome_message)
      @welcome_message
    end

    def build_welcome_message
      addressed_as = @user.name.to_s.scan(/\w+/).join(' ').titleize 

      if @user.password_digest.blank?
        @token = @user.tokens.detect{|token| token.kind.to_s == 'signup' and !token.expired?}
        @token ||= Token.make!(@user, :kind => :signup)
        @token.expires_at = nil
        @token.save

        @welcome_message = <<-__.unindented

          Hi #{ addressed_as } -

          We haven't heard from you in a while.

          Please click

            #{ activate_url(@token) }
          
          to activate your account.

          #{ Mailer.signature }
        __
      else
        @welcome_message = <<-__.unindented

          Hi #{ addressed_as } -

          We haven't heard from you in a while.

          Please click

            #{ login_url(:email => @user.email) }
          
          to login to your account.

          #{ Mailer.signature }
        __
      end
    end
  end
end
