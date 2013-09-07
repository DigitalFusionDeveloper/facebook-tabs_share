# force rails const_missing to preload these classes
#
    ActionController
    ActionController::Base

# support for using named routes from the console
#
  module Kernel
  private
    def use_named_routes_in_the_console! options = {}
      include ActionController::UrlWriter
      options.to_options!
      options.reverse_merge!(:host => 'localhost', :port => 3000)
      default_url_options.reverse_merge!(options)
    end
  end

# support for *** immediate *** render/redirection
#
  ActionController::Base.module_eval do
    class RenderException < ::Exception
    end

    class RedirectException < ::Exception
    end

    def redirect_to!(*args, &block)
      redirect_to(*args, &block)
      raise RedirectException.new
    end

    def render!(*args, &block)
      render(*args, &block)
      raise RenderException.new
    end

    rescue_from(RedirectException) do |e|
      nil
    end

    rescue_from(RenderException) do |e|
      nil
    end
  end
  
# protect against reloading
#
  RailsExt = 42 unless defined?(RailsExt)
