namespace :logs do
  task :rotate do
    Dir.chdir(Rails.root) do
      system './script/logrotate'
    end
  end
end
