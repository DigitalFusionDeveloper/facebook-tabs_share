# the normal rails preamble
#
  require File.expand_path('../boot', __FILE__)

## http://mongoid.org/docs/installation/configuration.html
#
  ### require 'rails/all'
  require "action_controller/railtie"
  require "action_mailer/railtie"
  require "active_resource/railtie"
  require "rails/test_unit/railtie"
  require "sprockets/railtie"

## teh bundler
#
  if defined?(Bundler)
    ActiveSupport::Deprecation.silence do
    # If you precompile assets before deploying to production, use this line
    #Bundler.require(*Rails.groups(:assets => %w(development test)))
    # If you want your assets lazily compiled in production, use this line
      Bundler.require(:default, :assets, Rails.env)
    end
  end

# RAILS_STAGE
#
  RAILS_STAGE = ENV['RAILS_STAGE'] ? ActiveSupport::StringInquirer.new(ENV['RAILS_STAGE']) : nil
  def Rails.stage() RAILS_STAGE end
  def Rails.stage?() RAILS_STAGE end

# finally, the application initializer
#
  module Dojo4
    class Application < Rails::Application
        ### config.action_view.javascript_expansions[:defaults] ||= []
        ### config.action_view.javascript_expansions[:defaults] += %( dao )

        ### config.action_view.stylesheet_expansions[:defaults] ||= []
        ### config.action_view.stylesheet_expansions[:defaults] += %( dao )


      # Settings in config/environments/* take precedence over those specified here.
      # Application configuration should go into files in config/initializers
      # -- all .rb files in that directory are automatically loaded.

      # Custom directories with classes and modules you want to be autoloadable.
      # config.autoload_paths += %W(#{config.root}/extras)
      config.autoload_paths += %W(#{config.root}/lib)

      # Only load the plugins named here, in the order given (default is alphabetical).
      # :all can be used as a placeholder for all plugins not explicitly named.
      # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

      # Activate observers that should always be running.
      # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

      # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
      # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
      # config.time_zone = 'Central Time (US & Canada)'

      # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
      # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
      # config.i18n.default_locale = :de

      # Configure the default encoding used in templates for Ruby 1.9.
      config.encoding = "utf-8"

      # Configure sensitive parameters which will be filtered from the log file.
      config.filter_parameters += [:password, :passphrase]

      # Use SQL instead of Active Record's schema dumper when creating the database.
      # This is necessary if your schema can't be completely dumped by the schema dumper,
      # like if you have constraints or database-specific column types
      # config.active_record.schema_format = :sql

      # Enforce whitelist mode for mass assignment.
      # This will create an empty whitelist of attributes available for mass-assignment for all models
      # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
      # parameters by using an attr_accessible or attr_protected declaration.
      # config.active_record.whitelist_attributes = true

      # Enable the asset pipeline
      config.assets.enabled = true

      # Version of your assets, change this if you want to expire all your assets
      config.assets.version = '1.0'

      Dir.glob( Rails.root.join("vendor", "assets", "stylesheets", "**", "**").to_s ).each{|dir| config.assets.paths << dir if test(?d, dir)}

      # Bundler.require *Rails.groups(:assets => %w(development test production))

      # sometimes vendored gems are saweet
      #
        vendor_gem_paths = Dir.glob("vendor/gems/*/lib").sort
        vendor_gem_paths.each do |vendor_gem_path|
          $LOAD_PATH.unshift(vendor_gem_path)
          config.autoload_paths.unshift(vendor_gem_path)
        end

      # include rails root
      #
        $LOAD_PATH.push(Rails.root) unless $LOAD_PATH.include?(Rails.root)

      # local libs/gems that can/must be loaded *before* rails initializer
      #
        require File.join(Rails.root, 'lib/app.rb')
     
      # local gems/libs that can/must be loaded *inside* rails initializer
      #
        require 'openssl' unless defined?(::OpenSSL)
        require 'rubyext' unless defined?(::RubyExt)
        require 'slug' unless defined?(::Slug)
        require 'map' unless defined?(::Map)
        require 'fattr' unless defined?(::Fattr)
        require 'thread' unless defined?(::Mutex)
        require 'coerce' unless defined?(::Coerce)
        require 'encoder' unless defined?(::Encoder)
        require 'encryptor' unless defined?(::Encryptor)
        require 'shared' unless defined?(::Shared)
        require 'bcrypt' unless defined?(::BCrypt)
        require 'util' unless defined?(::Util)
        require 'rails_current' unless defined?(::Current)
        require 'rails_helper' unless defined?(::Helper)
        require 'dao' unless defined?(::Dao)
        require 'tagz' unless defined?(::Tagz)

        require File.join(Rails.root, 'lib/rubyext.rb') unless defined?(::RubyExt)
        require File.join(Rails.root, 'lib/railsext.rb') unless defined?(::RailsExt)
        require File.join(Rails.root, 'lib/fake.rb') unless defined?(::Fake)
        require File.join(Rails.root, 'lib/settings.rb') unless defined?(::Settings)

        require File.join(Rails.root, 'lib/ggeocode.rb') unless defined?(::GGeocode)
        require File.join(Rails.root, 'lib/placeholder.rb') unless defined?(::Placeholder)
        require File.join(Rails.root, 'lib/template.rb') unless defined?(::Template)
        require File.join(Rails.root, 'lib/constraints.rb') unless defined?(::Constraints)
        require File.join(Rails.root, 'lib/before_render.rb') unless defined?(::BeforeRender)
        require File.join(Rails.root, 'lib/directory_importer.rb') unless defined?(::DirectoryImporter)
        require File.join(Rails.root, 'lib/asset_processor.rb') unless defined?(::AssetProcessor)
        require File.join(Rails.root, 'lib/iloop_mfinity.rb') unless defined?(::ILoop)


      #
      #
        config.after_initialize do
          require File.join(Rails.root, 'lib/api.rb') unless defined?(Api)
        end

        config.autoload_paths << 'lib'

        config.paths['app/models'] << 'lib/app/models'

        ActiveSupport::Deprecation.silence do
        end
    end
  end
