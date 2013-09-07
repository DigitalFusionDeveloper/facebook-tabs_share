namespace :cache do
  task :clear => :environment do
    App.clear_cache!
  end
end
