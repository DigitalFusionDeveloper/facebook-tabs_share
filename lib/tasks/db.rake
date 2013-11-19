db_namespace = namespace(:db) do
##
#
  if Rails.env.production?
    task :migrate => :dump
  end

##
#
  desc 'enable text search'
  task :enable_text_search => :environment do
    p App.db_enable_text_search!
  end

##
#
  desc 'dump the db using mongodump (rtfm)'
  task(:dump, [:timestamp] => :dumpdir) do |task, options|
  # setup dump directory
  #
    current_timestamp = Time.now.strftime('%Y%m%d%H%M%S')

    options.with_defaults(
      :timestamp => (ENV['timestamp']  || ENV['TIMESTAMP']),
      :basename => (ENV['basename']  || ENV['basename']),
      :directory => (ENV['directory']  || ENV['DIRECTORY'])
    )
    basename = options[:basename]
    timestamp = options[:timestamp]
    directory = options[:directory]

  # make the directory
  #
    directory ||= File.join(@dumpdir, basename || timestamp || current_timestamp)
    FileUtils.rm_rf(directory)
    FileUtils.mkdir_p(directory)
    directory = File.expand_path(directory)

  # dump the db into it
  #
    # --oplog
    command = "mongodump --out #{ directory.inspect } #{ mongo_cmd_line_connection }"
    spawn(command, :report => directory)

  # mongo makes a subdirectory named after the database - we like our shit
  # neat so name it 'data' and compress it
  #
    glob = File.join(directory, '*')
    src = Dir.glob(glob).first
    dst = File.join(File.dirname(src), 'data')
    FileUtils.mv(src, dst)
    Dir.chdir(directory){ spawn("tar cvfz data.tar.gz ./data && rm -rf ./data", :report => false) }
  end

##
#
  desc 'load the db using mongoload (rtfm)'
  task(:load, [:timestamp] => :dumpdir) do |task, options|
  # scan for a previously dumped db.  we load the most recent unless
  # something else is specified
  #
    glob = File.join(Rails.root, 'db/dump/' + ('[0-9]'*14))
    db_dumps = Dir.glob(glob).sort
    most_recent = db_dumps.last
    most_recent_timestamp = File.basename(most_recent) if most_recent
    current_timestamp = most_recent_timestamp

  # setup
  #
    options.with_defaults(
      :timestamp => (ENV['timestamp']  || ENV['TIMESTAMP']),
      :basename => (ENV['basename']  || ENV['basename']),
      :directory => (ENV['directory']  || ENV['DIRECTORY'])
    )
    basename = options[:basename]
    timestamp = options[:timestamp]
    directory = options[:directory]

    settings = Settings.for('config/mongo.yml')
    database = App.db_name or abort('no database')

    directory ||= File.join(@dumpdir, basename || timestamp || current_timestamp)
    directory = File.expand_path(directory)

  # push sacred data
  #
    sacred = {
      'system.users' => nil
    }

=begin
    sacred.keys.each do |collection|
      status, stdout, stderr = systemu("mongoexport #{ mongo_cmd_line_connection } --collection #{ collection.inspect }")
      abort("failed to dump sacred data #{ collection.inspect }") unless status==0
      sacred[collection] = stdout
    end
=end

  # unpack the data and suck that bad boy into our db
  #
    Dir.chdir(directory) do
      cwd = File.expand_path(Dir.pwd)
      puts "### cwd: #{ cwd }"

      spawn("tar xvfz data.tar.gz", :report => false)

      `mongod --setParameter textSearchEnabled=true`

      begin                                                                                                                                                                     
        Dir.chdir('./data') do                                                                                                                                                  
          spawn("rm -rf system\.*")                                                                                                                                             
          cwd = File.expand_path(Dir.pwd)                                                                                                                                       
          puts "### cwd: #{ cwd }"                                                                                                                                              
                                                                                                                                                                                
          Dir.glob('*.bson') do |bson|                                                                                                                                          
            collection = bson.sub(/\.bson\Z/, '')                                                                                                                               
            if bson =~ /\Asystem\./                                                                                                                                             
              warn "skipping system collection #{ collection.inspect }"                                                                                                         
            end                                                                                                                                                                 
            #next if bson =~ /\Asystem\./                                                                                                                                       
            #command = "mongorestore #{ mongo_cmd_line_connection } --noIndexRestore --objcheck --collection #{ collection.inspect } #{ bson.inspect }"                         
            command = "mongorestore #{ mongo_cmd_line_connection } --objcheck --collection #{ collection.inspect } #{ bson.inspect }"                                           
            spawn(command, :report => command)                                                                                                                                  
          end                                                                                                                                                                   
        end                                                                                                                                                                     
      ensure                                                                                                                                                                    
        spawn("rm -rf ./data", :report => false)                                                                                                                                
      end                             

=begin
      begin
        command = "mongorestore --drop --noIndexRestore --objcheck #{ mongo_cmd_line_connection } ./data"
        spawn(command, :report => directory)
      ensure
        spawn("rm -rf ./data", :report => false)
      end
=end
    end

  # pop sacred data
  #
    sacred.each do |collection, data|
      if data
        status, stdout, stderr = systemu("mongoimport #{ mongo_cmd_line_connection } --upsert --collection #{ collection.inspect }", :stdin => data)
        abort("failed to load sacred data #{ collection.inspect }") unless status==0
      end
    end

  # ensure indexes are built in background
  #
    command = "nohup bundle exec rake db:mongoid:create_indexes >/dev/null &"
    puts "### system: #{ command }"
    system(command)
  end

  def spawn(command, options = {})
    status, stdout, stderr = systemu(command)
    if status == 0
      report = options[:report] || options['report']
      STDOUT.puts(report || stdout) unless report==false
    else
      STDOUT.puts(stdout)
      STDERR.puts(stderr)
      exit(status.exitstatus)
    end
  end

##
#
  task :dumpdir => :environment do
    if cap_path = App.cap?
      cap_dumpdir = File.join(cap_path, 'db', 'dump')
      dumpdir = File.join(Rails.root, 'db', 'dump')
      FileUtils.mkdir_p(cap_dumpdir)
      FileUtils.rm_rf(dumpdir)
      FileUtils.ln_s(cap_dumpdir, dumpdir)
      @dumpdir = dumpdir
    else
      @dumpdir = File.join(Rails.root, "db", "dump")
      FileUtils.mkdir_p(@dumpdir)
    end
  end

##
#
  namespace :test do
  ## kill the default db:test:prepare
  #
    begin
      Rake::Task["db:test:prepare"].tap do |task|
        task.instance_eval do
          @actions.clear
        end
      end
    rescue Object
    end

  ## build a mo-betta one that runs only when needed
  #
    task :prepare => :environment do |task, options|
      force = !(ENV['FORCE'] || ENV['force']).blank?

      test_env do
        if force or !prepared?
          STDERR.puts
          STDERR.puts('db:test:prepare : building test db *** ONCE *** - you can force a rebuild with "rake db:test:prepare:force"')
          STDERR.puts
          test_env do
            `RAILS_ENV=test rake db:bounce 2>&1`
            db_snapshot = App.db_snapshot
            open(test_db_yml, 'w'){|fd| fd.write(db_snapshot.to_yaml)}
            prepared!
          end
        else
          STDERR.puts
          STDERR.puts('db:test:prepare : skipping...')
          STDERR.puts
        end
      end
    end

    namespace :prepare do
      task :force do
        FileUtils.rm_f(prepared_guard)
        Rake::Task['db:test:prepare'].invoke
      end
    end

    private
      def test_db_yml
        @test_db_yml ||= File.join(Rails.root, 'test/db.yml')
      end

      def prepared_guard
        @prepared_guard ||= File.join(Rails.root, 'test/db.yml')
      end

      def prepared?
        test(?e, prepared_guard)
        #ActiveRecord::Base.connection.table_exists?(:db_prepared)
      end

      def prepared!
        FileUtils.touch(prepared_guard)
        #ActiveRecord::Base.connection.create_table(:db_prepared) unless prepared?
      end

      def mongo_cmd_line_connection
        # grok the database connection
        connection = []

        Mongoid.default_session # Force the setting to be parsed
        settings = Mongoid.sessions[:default]
        connection.push('--db',settings[:database].inspect)
        connection.push('--host',settings[:hosts].first.inspect)
        connection.push('--username',settings[:username].inspect) unless settings[:username].blank?
        connection.push('--password',settings[:password].inspect) unless settings[:password].blank?
        connection.push('--ssl') if(settings[:options] && settings[:options][:ssl])
        connection.join(' ')
      end

      def test_env
        Rails.env.tap do |env|
          previous = env.to_s 
          env.replace('test')
          return(yield) if block_given?
          env.replace(previous)
        end
      end
  end

##
#
  desc "db:drop db:create db:seed db:migrate db:mongoid:create_indexes"
  task(:bounce => %w(db:drop db:create db:seed db:migrate db:mongoid:create_indexes)) do
    Rake::Task['db:test:prepare:force'].invoke if Rails.env.development?
  end

##
#
  
end
