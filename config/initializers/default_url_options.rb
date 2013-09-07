
# config/initializers/default_url_options.rb
 
if Rails.env.production? and Rails.stage

  url = App.settings[Rails.stage]['url']

  if url
    uri = URI.parse(url)

    host = uri.host
    protocol = uri.scheme

    DefaultUrlOptions.configure!(
      :protocol => protocol,
      :host     => host
    )
  end

end
