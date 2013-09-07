namespace :db do
  namespace :import do
    task :all => :environment

    def self.generate_directory_importer_task!(directory)
    #
      directory = File.expand_path(directory.to_s)
      basename = File.basename(directory) 

      plural = basename.pluralize
      singluar = basename.singularize
      const = basename.singularize.camelize

    #
      return false if Rake.application.lookup(plural)

    #
      task :all => plural

      namespace plural do
        task :all, [:directory, :directories] => :environment do |task, options|
        #
          options.with_defaults(
            :directory => (ENV['directory']  || ENV['DIRECTORY']),
            :directories => (ENV['directories']  || ENV['DIRECTORIES']),
            :force => (ENV['force']  || ENV['FORCE'] || !!@force),
          )
          directory = options[:directory]
          directories = options[:directories]
          force = options[:force]
          
        #
          model_class =
            begin
              Object.const_get(const)
            rescue Object
              STDERR.puts "failed to find model_class for #{ directory }"
              abort
            end

          importer_class = nil

          candidates =
            %W(
              DirectoryImporter
              Importer
            )

          candidates.each do |candidate|
            begin
              break(importer_class = model_class.const_get(candidate))
            rescue Object
              next
            end
          end

          unless importer_class
            unless ENV['DIRECTORY_IMPORTER_VIVIFY'] == 'false'
              const = DirectoryImporter.name
              model_class.send(:const_set, const, Class.new(DirectoryImporter))
              importer_class = model_class.const_get(const, inherit=false)
              STDERR.puts "WARNING: using automatic directory_importer #{ importer_class.name }"
            else
              STDERR.puts "FAILURE: no importer_class for #{ directory }"
              abort
            end
          end


        #
          rails_root = Pathname.new(Rails.root)
          prefix = Rails.root.join("db/import/#{ basename }")
          glob = prefix.join('**/**')

          entries = [directory, directories].compact.flatten
          if entries.empty?
            entries = Dir.glob(glob)
          end

          entries.each do |entry|
          #
            next unless test(?d, entry)
            next unless importer_class.imports?(entry)

          #
            directory = File.expand_path(entry)
            path = Pathname.new(directory).expand_path.relative_path_from(prefix).to_s

          #
            importer = importer_class.for(prefix, path, :force => force)

            STDOUT.puts "importing: #{ directory }..."

          #
            if importer.save
              if importer.imported?
                STDOUT.puts "imported: #{ path }."
              else
                STDOUT.puts "fresh: #{ path }."
              end
            else
              STDERR.puts "FAILED: #{ path }"
              STDERR.puts
              STDERR.puts "  ERRORS: #{ path }"
              STDERR.puts Util.indent(importer.errors.to_text)
              STDERR.puts
              #STDERR.puts "  ATTRIBUTES: #{ path }"
              #STDERR.puts Util.indent(importer.attributes.inspect)
              #STDERR.puts
              STDERR.puts "  NEW_RECORD?: #{ importer.model.new_record? }"
              STDERR.puts
              abort
            end
          end
        end

        task :force do
          @force = true
          Rake::Task["db:import:#{ plural }:all"].invoke
        end
      end

      desc "import #{ plural } from db/import/#{ plural }/*"
      task "#{ plural }" => "#{ plural }:all"
    end

  # generate tasks for all directorys in db/import/*
  #
    Dir.glob(Rails.root.join('db/import/*')).sort.each do |directory|
      generate_directory_importer_task!(directory)
    end

    task :default => :all

    task :content => :contents
  end

  task 'import' => 'import:all'
end
