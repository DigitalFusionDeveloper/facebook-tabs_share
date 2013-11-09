Rails.configuration.after_initialize do
  if App.sekrets.has_key?(:aws)
    Upload.config.update(:aws => App.sekrets[:aws])
  end

  # Upload.config.update(:strategy => 'grid_fs')
  Upload.config.update(:strategy => 's3')
  #Upload.config.update(:strategy => 'fs')
end
