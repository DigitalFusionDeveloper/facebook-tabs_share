class Su::ApplicationController < Su::Controller
  def index
  ## list users
  #
    @users = User.all.order_by([:email, :asc])
    return if request.get?

  ## su 
  #
    email = params[:email] || (params[:su]||{})[:email]
    return if email.blank?

    if email != effective_user.email
      user = User[email]
      login!(user)
      message("Logged in as #{ email.inspect }", :class => "success")
      redirect_to(:action => :index)
      return
    end

    message 'oops!', :class => 'error'
  end

  def logs
    log = File.join(Rails.root, "log", "#{ Rails.env }.log")
    @lines = `tail -1024 #{ log }`.split(/\n/).reverse
    respond_to do |wants|
      wants.html{ render }
      wants.json{ render(:json => @lines) }
    end
  end

protected
  def login!(*args, &block)
    options = args.extract_options!.to_options!
    user = args.shift || options[:user] or raise(ArgumentError, 'no user!')
    id = user.is_a?(User) ? user.id : user
    session[:effective_user] = id
  end
end
