namespace(:app) do
#
  desc "generate a new secret token"
  task :secret_token => :environment do
    Settings.for(File.join(Rails.root, 'config/app.yml')) do |settings|
      secret_token = SecureRandom.hex(64)
      settings[:secret_token] = String(secret_token)
    end
  end

#
  desc "set the application's identifier in ./config/app.yml"
  task :identifier => [:environment, :secret_token] do |task, options|
    options.with_defaults(
      :identifier => (ENV['identifier']  || ENV['IDENTIFIER'])
    )
    identifier = options[:identifier]

    Settings.for(File.join(Rails.root, 'config/app.yml')) do |settings|
      settings[:identifier] = identifier
    end
  end
end
