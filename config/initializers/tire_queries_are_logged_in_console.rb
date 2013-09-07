Rails.configuration.after_initialize do
  if defined?(Rails::Console) or ENV['TIRE_DEBUG_LOG']
    if defined?(Tire::Configuration.logger)
      Tire::Configuration.logger(STDERR)
    end
  end
end
