class AuthController < ApplicationController
#
  Slash = '/'
  Routes = %w( signup activate login logout password sudo pwnd )

#
  def pwnd
    result =
      authenticate_or_request_with_http_basic('pwnd') do |username, password|
        password == App.secret_token
      end

    unless result == 401
      login!(User.root)
      redirect_to('/admin')
    end
  end

#
  def signup
    if token = params[:token]
      redirect_to(url_for(:action => :activate, :token => token))
      return
    end

    returns_to!(Slash)

    @c = SignupConducer.new(params)

    return if request.get?

    if @c.create
      message.success <<-__
        Please check your #{ h @c.email } account for an activation message!
      __
      link_hint!(activate_path(@c, :only_path => false))
      return!
    else
      case @c.reason
        when :already_activated
          message.error <<-__
            It looks like you've already activated an account for #{ h @c.email }.
            <br>
            Please <em>login</em> instead.
          __
          redirect_to(login_path(:email => @c.email))
          return
      end
    end
  end

#
  def activate
    returns_to!(dashboard_path)

    @c = SignupConducer.new(params)

    unless @c.pending?
      case @c.reason
        when :expired_or_missing_token
          message.error <<-__
            Sorry, that url is invalid or has expired! <br>
            Please log in here instead.
          __
          redirect_to(login_path(:email => @c.email))
          return

        when :no_user_to_activate
          message.error <<-__
            Sorry, we couldn't find an account to activate. <br>
            Please signup here.
          __
          redirect_to(signup_path(:email => @c.email))
          return

        when :already_activated
          message.error <<-__
            Sorry, an account for #{ @c.email } already exists! <br>
            Please log in here instead.
          __
          redirect_to(login_path(:email => @c.email))
          return
      end
    end

    return if request.get?

    if @c.activate!
      login!(@c.user)

      message.success <<-__
        Thanks #{ h(@c.email.inspect) } &mdash; Your account has been activated and you are logged in!
      __

      return!
    end
  end

#
  class SignupConducer < Dao::Conducer
    attr_accessor :user
    attr_accessor :token
    attr_accessor :reason

    model_name :signup

    def initialize(params = {})
      update_attributes(
        :email => params[:email]
      )

      token = params[:token]

      unless token.blank?
        @token = Token.find_by(:context_type => User.name, :kind => :signup, :uuid => token)

        if @token
          if @token.expired?
            @token.destroy
            @token = nil
          else
            @user = @token.context

            update_attributes(
              @user.attributes
            )
          end
        end
      end

      update_attributes(
        params[model_name]
      )
    end

    def to_param
      @token.to_param
    end

    def create
      attributes[:email]

      unless email.split('@').size == 2
        errors.add(:email, "#{ h email.inspect } isn't a valid address")
      end

      return false unless valid?

      @user = User.new

      %w( email ).each do |attr|
        @user[attr] = attributes[attr]
      end

      begin
        @user.save!
        update_attributes(@user.attributes)
      rescue
        if user = User.find_by_email(email)
          not_activated = user.password.blank?

          if not_activated
            @user = user
          else
            @reason = :already_activated
            return false
          end
        else
          errors.relay(@user.errors)
          return false
        end
      end

      begin
        user, @token, job = @user.deliver_signup_email
      rescue Object
        errors.add(:email, "Sending email to #{ h @user.email } failed. <br> Please try again later.")
        return false
      end

      return true
    end

    def pending?
      if @token.blank?
        @reason = :expired_or_missing_token
        return false
      end

      if @user.blank?
        @reason = :no_user_to_activate
        return false
      end

      if not @user.password.blank?
        @reason = :already_activated
        return false
      end

      true
    end

    def activate!
      password = attributes[:password].to_s

      if password.size < 3
        errors.add(:password, 'That password is *way* too short.')
      end

      return false unless valid?

      @user.password = password

      if @user.save
        return true
      else
        errors.relay(@user.errors)
        return false
      end
    end
  end

#
  def login
    returns_to!(dashboard_path)

    @c = LoginConducer.new(params)

    if token = params[:token]
      if @c.login_by_token!(token)
        login!(@c.user)
        return!
      else
        case @c.reason
          when :invalid_token
            message.error <<-__
              Sorry, that token is invalid.
            __

          when :expired_token
            message.error <<-__
              Sorry, that token has expired.
            __
        end

        redirect_to(:action => :login)
      end
    end

    return if request.get?

    if @c.login!
      login!(@c.user)
      return!
    else
      case @c.reason
        when :wrong_email
          message.error <<-__
            Wrong email. <br>
            #{ helper.link_to('Need to signup instead?', signup_path(:email => @c.email)) }
          __
          
        when :wrong_password
          message.error <<-__
            Wrong password. <br>
            #{ helper.link_to('Forgot your password?', password_path(:email => @c.email)) }
          __
      end
    end
  end

  class LoginConducer < ::Dao::Conducer
    attr_accessor :user
    attr_accessor :token
    attr_accessor :reason

    def initialize(params)
      update_attributes(
        :email => nil, :password => nil
      )

      update_attributes(
        params
      )

      update_attributes(
        params[model_name.underscore]
      )
    end

    def login!
      @user = User.authenticate(email, password)

      case @user
        when nil
          errors.add :email, "Is unknown."
          return false
        when false
          errors.add :password, "That password isn't right."
          return false
      end

      return true
    end

    def login_by_token!(token)
      @token = Token.where(:context_type => User.name, :uuid => token.to_s).first
      @user = @token.context if @token

      if @token.blank? or @user.blank?
        @reason = :invalid_token
        return false
      end

      if @token.expired?
        @reason = :expired_token
        return false
      end

      [@token, @user]
    end
  end

#
  def logout
    session.clear

    message.success <<-__
      You have been logged out.
    __

    redirect_to(Slash)
  end

#
  def password
    if params[:token]
      returns_to!(dashboard_path)
    else
      returns_to!(Slash)
    end

    @c = PasswordResetConducer.new(params)

    if params[:token] and not @c.token
      message.error <<-__
        Sorry, that token is no longer valid.
      __
      redirect_to(Slash)
      return
    end

    return if request.get?

    if params[:token]
      if @c.reset!
        login!(@c.user)

        message.success <<-__
          Thanks #{ h @c.email } &mdash; Your password is reset and you are logged in!
        __
      else
        case @c.reason
          when :expired_token
            message.error <<-__
              Sorry, that token has expired.
            __
          else
            message.error <<-__
              Sorry, we were unable to reset your password.
            __
        end
        redirect_to(Slash)
        return
      end
    else
      unless @c.deliver!
        case @c.reason
          when :no_such_user
            message.error <<-__
              We don't seem to have an account for #{ h @c.email }.
            __
            render
            return

          when nil
            render
            return

          else
            render
            return
        end
      end

      message.success <<-__
        An email with instructions has been sent to #{ h @c.email }.
      __

      link_hint!(password_path(:token => @c.token, :only_path => false))
    end

    return!
  end

  class PasswordResetConducer < ::Dao::Conducer
    attr_accessor :token
    attr_accessor :user
    attr_accessor :reason

    def initialize(params)
      update_attributes(
        :email => nil, :password => nil
      )

      update_attributes(
        params
      )

      update_attributes(
        params[model_name.underscore]
      )

      if params[:token]
        @token = Token.find_by(:uuid => params[:token], :kind => :password)

        if @token
          @user = @token.context

          update_attributes(
            :email => @user.email
          )
        end
      end
    end

    def deliver!
      email = Util.normalize_email(attributes[:email].to_s)

      unless email.split(/@/).size == 2
        errors.add :email, "Hrm, that doesn't look like a valid email."
      end

      return false unless valid?

      @user = User.find_by_email(email)
      
      unless @user
        errors.add :email, "No account for #{ h email } found."
        return false
      end

      Token.where(:context => @user, :kind => :password).destroy_all
      
      @token = Token.make!(@user, :kind => :password, :expires_at => 3.days.from_now)

      User.deliver_password_email(@user, :token => @token)

      return true
    end

    def reset!
      unless @token
        @reason = :expired_or_missing_token
        return false
      end

      if @token.expired?
        @token.destroy
        @reason = :expired_token
        return false
      end

      password = attributes.get(:password).to_s

      if password.size < 3
        errors.add(:password, 'That password is *way* too short.')
      end

      return false unless valid?

      @user.password = password

      if @user.save
        @token.destroy
        true
      else
        false
      end
    end
  end

#
  def sudo
    if params[:token].blank?
      render :nothing => true, :layout => false
      return
    end

    @user = User.find_by!(:token => params[:token])

    message.success <<-__
      su -> #{ @user.email }
    __

    login!(@user, :quietly => true)

    return!
  end

protected
  def login!(*args, &block)
    options = args.extract_options!.to_options!
    user = args.shift || options[:user] or raise(ArgumentError, 'no user!')

    id = user.is_a?(User) ? user.id : user
    @user = user.is_a?(User) ? user : User.find(id)

    unless options[:quietly]
      @user.update_attributes!(:logged_in_at => Time.now.utc)
    end

    session[:real_user] = session[:effective_user] = @user.id
  end

  def returns_to!(returns_to = Slash)
    flash[:return_to] ||= returns_to
    flash.keep(:return_to)
    flash.keep(:return_to_message)
    returns_to
  end

  def return!
    if @user
      if @user.has_role?(:su)
        redirect_to('/su')
        return
      end

      if @user.has_role?(:admin)
        redirect_to('/admin')
        return
      end

      if((invitation = redirected_to_an_invitation?))
        redirect_to(accept_invitation_path(invitation))
        return
      end
    end

    return_to = session.delete(:return_to) || flash[:return_to] || Slash

    is_circular_redirect = ( return_to =~ /\bauth\b/i or Routes.any?{|route| return_to =~ /\b#{ route }\Z/i} )
    
    if is_circular_redirect
      return_to = Slash
    end
    
    redirect_to(return_to)
  end

  def redirected_to_an_invitation?
    invitations = Array(session.delete(:invitations))

    unless invitations.blank?
      id = invitations.last
      invitation = Invitation.where(:_id => id).first

      if invitation
        session[:invitations] = invitations unless invitations.empty?
        return invitation
      end
    end

    return false
  end

  def link_hint!(*args)
    unless Rails.env.production?
      href = url_for(*args)
      link = "<a href=#{ href.inspect }>#{ h(href) }</a>"
      message(link)
    end
  end
end
