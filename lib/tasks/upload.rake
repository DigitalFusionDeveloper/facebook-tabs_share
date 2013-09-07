

  namespace :upload do
    namespace :process do
      task :all => :environment do

        Upload.process_all do |upload, processing_step|
          puts "Upload.processing: upload=#{ upload.id }, name=#{ processing_step.name.inspect }"
        end

      end
    end
  end



