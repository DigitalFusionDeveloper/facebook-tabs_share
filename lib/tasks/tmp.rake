namespace :tmp do

  namespace :uploads do

    desc "clears upload tmp files"

    task :clear => :environment do
      quietly{ Upload.tmpwatch! }
    end

  end

  task :clear => 'tmp:uploads:clear'

end
