class Admin::ApplicationController < Admin::Controller
  def index
    redirect_to admin_users_path
  end

protected
  def login!(*args, &block)
    options = args.extract_options!.to_options!
    user = args.shift || options[:user] or raise(ArgumentError, 'no user!')
    id = user.is_a?(User) ? user.id : user
    session[:effective_user] = id
  end
end
