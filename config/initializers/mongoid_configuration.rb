
Rails.configuration.after_initialize do


# log queries when in console mode
#
  if defined?(Rails::Console)
    if defined?(Mongoid) and defined?(Moped)
      logger = Logger.new(STDERR)
      Mongoid.logger = logger
      Moped.logger = logger
    end
  end

# enable text search
# 
  begin
    #App.db_enable_text_search!
  rescue Object => e
    warn 'could not enable text search!'
  end

end
