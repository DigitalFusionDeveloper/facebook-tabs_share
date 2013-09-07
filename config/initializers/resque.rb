
=begin

quietly do
  require 'resque'
end

Resque.redis = App.redis

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    if forked
      Redis.current.quit
    end
  end
end

=end
