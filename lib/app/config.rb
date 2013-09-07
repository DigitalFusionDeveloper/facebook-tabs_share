module App
  def App.configure_environment(*args)
    options = args.extract_options!.to_options!
    env = args.shift || options[:env] || Rails.env
    config = args.shift || options[:config] || Rails.application.config
    env = ActiveSupport::StringInquirer.new(env.to_s)

    send("configure_environment_#{ env }", config)

    App.configure_cache()
    App.configure_email()
  end

  def App.configure_cache(*args)
    options = args.extract_options!.to_options!
    env = args.shift || options[:env] || Rails.env
    config = args.shift || options[:config] || Rails.application.config
    env = ActiveSupport::StringInquirer.new(env.to_s)

    if env.production? or ENV['RAILS_CACHE']
      config.cache_store = [:redis_store, App.redis_store_config]
      # config.cache_store = [:mongoid_store, {:expires_in => 42.years}]
    end
  end

  def App.configure_email(*args)
    options = args.extract_options!.to_options!
    env = args.shift || options[:env] || Rails.env
    config = args.shift || options[:config] || Rails.application.config
    env = ActiveSupport::StringInquirer.new(env.to_s)

    if env.production? or ENV['RAILS_EMAIL']
      config.action_mailer.default_url_options   = defined?(DefaultUrlOptions) ? DefaultUrlOptions : {}
      config.action_mailer.perform_deliveries    = true
      config.action_mailer.raise_delivery_errors = true

    # See: https://github.com/dojo4/aws/blob/master/ses.md
    #
      config.action_mailer.smtp_settings = {
        :user_name            => ses_smtp_settings.user_name,
        :password             => ses_smtp_settings.password,
        :address              => ses_smtp_settings.address,
        :domain               => ses_smtp_settings.domain,
        :port                 => ses_smtp_settings.port,
        :authentication       => ses_smtp_settings.authentication.to_sym
      }

      config.action_mailer.delivery_method       = :smtp
    else
      config.action_mailer.perform_deliveries    = true
      config.action_mailer.raise_delivery_errors = true
      config.action_mailer.delivery_method       = :file
    end
  end

  def App.configure_environment_production(*args)
    options = args.extract_options!.to_options!
    config = args.shift || options[:config] || Rails.application.config

    # The production environment is meant for finished, "live" apps.
    # Code is not reloaded between requests
    config.cache_classes = true

    # Full error reports are disabled and caching is turned on
    config.consider_all_requests_local       = false
    config.action_controller.perform_caching = true
    #config.consider_all_requests_local       = true
    #config.action_controller.perform_caching = false

    # Specifies the header that your server uses for sending files
    #config.action_dispatch.x_sendfile_header = "X-Sendfile"

    # For nginx:
    # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

    # If you have no front-end server that supports something like X-Sendfile,
    # just comment this out and Rails will serve the files

    # See everything in the log (default is :info)
    # config.log_level = :debug

    # Use a different logger for distributed setups
    # config.logger = SyslogLogger.new

    # Use a different cache store in production
    # config.cache_store = :mem_cache_store

    # Disable Rails's static asset server
    # In production, Apache or nginx will already do this
    config.serve_static_assets = true
    
    # Compress JavaScripts and CSS
    config.assets.compress = true

    # Don't fallback to assets pipeline if a precompiled asset is missed
    config.assets.compile = true

    # Generate digests for assets URLs
    config.assets.digest = true

    # This makes asset compilation much faster
    config.assets.initialize_on_precompile = false

    # Enable serving of images, stylesheets, and javascripts from an asset server
    # config.action_controller.asset_host = "http://assets.example.com"
    # config.assets.precompile += %w[*.png *.jpg *.jpeg *.gif]

    # Disable delivery errors, bad email addresses will be ignored
    # config.action_mailer.raise_delivery_errors = false
    config.action_mailer.raise_delivery_errors = true

    # Enable threaded mode
    # config.threadsafe!

    # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
    # the I18n.default_locale when a translation can not be found)
    config.i18n.fallbacks = true

    # Send deprecation notices to registered listeners
    config.active_support.deprecation = :notify

    #config.log_to = %w[ file ]
    config.log_level = (Rails.stage && !Rails.stage.production?) ? :debug : :info

    if STDOUT.tty?
      #config.log_to = %w[ stdout file ]
    end
  end

  def App.configure_environment_development(*args)
    options = args.extract_options!.to_options!
    config = args.shift || options[:config] || Rails.application.config

    # In the development environment your application's code is reloaded on
    # every request. This slows down response time but is perfect for development
    # since you don't have to restart the web server when you make code changes.
    config.cache_classes = false

    # Log error messages when you accidentally call methods on nil.
    config.whiny_nils = true

    # Show full error reports and disable caching
    config.consider_all_requests_local       = true
    config.action_controller.perform_caching = !!ENV['RAILS_CACHE']

    # Print deprecation notices to the Rails logger
    config.active_support.deprecation = :log

    # Only use best-standards-support built into browsers
    config.action_dispatch.best_standards_support = :builtin

    # Raise exception on mass assignment protection for Active Record models
    #config.active_record.mass_assignment_sanitizer = :strict

    # Log the query plan for queries taking more than this (works
    # with SQLite, MySQL, and PostgreSQL)
    #config.active_record.auto_explain_threshold_in_seconds = 0.5

    # Do not compress assets
    config.assets.compress = false

    # Expands the lines which load the assets
    config.assets.debug = true

    # Set the logging destination(s)
    config.active_support.deprecation = :log
    #config.log_to = %w[ stdout file ]
    config.log_level = :info
  end

  def App.configure_environment_test(*args)
    options = args.extract_options!.to_options!
    config = args.shift || options[:config] || Rails.application.config

    # Settings specified here will take precedence over those in config/application.rb

    # The test environment is used exclusively to run your application's
    # test suite. You never need to work with it otherwise. Remember that
    # your test database is "scratch space" for the test suite and is wiped
    # and recreated between test runs. Don't rely on the data there!
    config.cache_classes = true

    # Configure static asset server for tests with Cache-Control for performance
    config.serve_static_assets = true
    config.static_cache_control = "public, max-age=3600"

    # Log error messages when you accidentally call methods on nil
    config.whiny_nils = true

    # Show full error reports and disable caching
    config.consider_all_requests_local       = true
    config.action_controller.perform_caching = false

    # Raise exceptions instead of rendering exception templates
    config.action_dispatch.show_exceptions = false

    # Disable request forgery protection in test environment
    config.action_controller.allow_forgery_protection    = false

    # Tell Action Mailer not to deliver emails to the real world.
    # The :test delivery method accumulates sent emails in the
    # ActionMailer::Base.deliveries array.
    config.action_mailer.delivery_method = :test

    # Raise exception on mass assignment protection for Active Record models
    # config.active_record.mass_assignment_sanitizer = :strict

    # Print deprecation notices to the stderr
    config.active_support.deprecation = :stderr

    #config.log_to = %w[file]
    config.log_level = :info
  end
end
