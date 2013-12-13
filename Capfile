## ensure we're running under 'bundle exec'
#
  unless ENV['BUNDLE_GEMFILE']
    command = "bundle exec cap #{ ARGV.join(' ') }"
    exec(command)
  end

## ensure the app is loaded - we need it to send email...
#
  unless defined?(Rails)
    rails_root = File.dirname(File.expand_path(__FILE__))
    load File.join(rails_root, 'config/environment.rb')
  end

## ensure a valid sekrets key is present
#
  unless Rails.root.join('.sekrets.key').exist?
    abort "you need a .sekrets.key to deploy ;-("
  end
  require 'sekrets/capistrano'

## boot cap libs
#
  load 'deploy' if respond_to?(:namespace) # cap2 differentiator
  Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

## cap-ssh
#
  require 'cap-ssh'

## colors
#
  require 'capistrano_colors'

## multistage (require 'capistrano/ext/multistage')
#
  set :stages, %w( staging production )
  set :default_stage, "staging"
  set :normalize_asset_timestamps, false

  location = fetch(:stage_dir, "config/deploy")
  unless exists?(:stages)
    set :stages, Dir["#{location}/*.rb"].map { |f| File.basename(f, ".rb") }
  end
  stages.each do |name|
    desc "Set the target stage to `#{name}'."
    task(name) do
      set :stage, name.to_sym
      load "#{location}/#{stage}"
    end
  end 
  namespace :multistage do
    desc "[internal] Ensure that a stage has been selected."
    task :ensure do
      if !exists?(:stage)
        if exists?(:default_stage)
          logger.important "Defaulting to `#{default_stage}'"
          find_and_execute_task(default_stage)
        else
          abort "No stage specified. Please specify one of: #{stages.join(', ')} (e.g. `cap #{stages.first} #{ARGV.last}')"
        end
      end 
    end
    desc "Stub out the staging config files."
    task :prepare do
      FileUtils.mkdir_p(location)
      stages.each do |name|
        file = File.join(location, name + ".rb")
        unless File.exists?(file)
          File.open(file, "w") do |f|
            f.puts "# #{name.upcase}-specific deployment configuration"
            f.puts "# please put general deployment config in config/deploy.rb"
          end
        end
      end
    end
  end
  on :start, "multistage:ensure", :except => stages + ['multistage:prepare']

## force a remote rebenv version iff a local one has been configured
#
  rails_root = File.expand_path(File.dirname(__FILE__))
  rbenv_version = File.join(rails_root, '.rbenv-version')
  if test(?e, rbenv_version)
    default_environment['RBENV_VERSION'] = IO.read(rbenv_version).strip
  end

## setup remote PATH.  it's important that this picks up rbenv!
#
  default_environment['PATH'] = (
    '/usr/local/rbenv/shims:/usr/local/rbenv/bin:' +
    '/usr/local/mongo/bin:' +
    default_environment.fetch('PATH', '') +
    '/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin'
  )

## suck in some app settings - we'll use the identifier to configure tons of
# stuff
#
  load File.join(File.join(rails_root, 'lib/settings.rb'))
  $settings = settings = Settings.for('config/app.yml')
  $stage = stage = ARGV.first
  stages = fetch(:stages)
  abort "stage #{ stage } not in #{ stages.join('|') }" unless stages.include?(stage)
  set(:settings, settings)
  set(:identifier, settings['identifier'])
  set(:url, settings[stage]['url'])
  set(:repository, settings['repository'] || "git@github.com:dojo4/#{ identifier }.git")
  set(:ip, settings['deploy'][stage]['ip'])
  set(:deploy_to, settings['deploy'][stage]['deploy_to'])

## make rake run in the proper environment
#
  set(:rake, "bundle exec rake")

## bundler (require 'bundler/capistrano.rb')
#
  namespace :bundle do
    task :symlinks, :roles => :app do
      shared_dir = File.join(shared_path, 'bundle')
      release_dir = File.join(current_release, '.bundle')
      run("mkdir -p #{shared_dir} && rm -rf #{release_dir} && ln -s -f -F #{shared_dir} #{release_dir}")
    end

    task :install, :except => { :no_release => true } do
      bundle_dir     = fetch(:bundle_dir,         " #{fetch(:shared_path)}/bundle")
      bundle_without = [*fetch(:bundle_without,   [:development, :test])].compact
      bundle_flags   = fetch(:bundle_flags, "--deployment --quiet")
      bundle_gemfile = fetch(:bundle_gemfile,     "Gemfile")
      bundle_cmd     = fetch(:bundle_cmd, "bundle")

      args = ["--gemfile #{fetch(:latest_release)}/#{bundle_gemfile}"]
      args << "--path #{bundle_dir}" unless bundle_dir.to_s.empty?
      args << bundle_flags.to_s
      args << "--without #{bundle_without.join(" ")}" unless bundle_without.empty?

      run "#{bundle_cmd} install #{args.join(' ')}"
    end
  end
  after 'deploy:update_code', 'bundle:symlinks'
  after "deploy:update_code", "bundle:install"

##
#
  namespace :suggest do
    namespace :db do
      namespace :mongoid do
        task :create_indexes, :roles => :app do
          stage = fetch(:stage)
          logger.important "YO! YOU MAY WANT TO RUN: cap #{ stage } db:mongoid:create_indexes"
        end
      end
    end
  end

## these tasks let us push and pull teh mongos across the wire.  dangerous!
#
  namespace :db do
    namespace :mongoid do
      task :create_indexes, :roles => :app do
        stage = fetch(:stage)
        run("cd #{ deploy_to }/current && RAILS_STAGE=#{ stage } bundle exec rake db:mongoid:create_indexes; true")
      end

    end

    task :bounce do
      stage = fetch(:stage)
      run("cd #{ deploy_to }/current && RAILS_STAGE=#{ stage } bundle exec rake db:bounce")
    end

    desc 'show remote db config'
    task :config do
    # local setup
    #
      user = fetch(:user)
      host = URI.parse(fetch(:url)).host

    # we need the remote database name and port
    #
      program = ' Mongoid.database.tap{|d| y(:port=>d.connection.port, :host=>d.connection.host, :database=>d.name)} '
      command = %[ ssh #{ user }@#{ host } 'cd #{ deploy_to }/current && bundle exec rails runner #{ program.inspect }' ]
      stdout = `#{ command }`
      status = $?
      abort("#{ command } # failed with #{ status.inspect }") unless status==0
      puts stdout
   end

    desc 'suck a remote database into local one'
    task :suck, :roles => :db do
      require 'fileutils'
      rails_root = File.expand_path(File.dirname(__FILE__))
      user = ENV['USER'] || 'cap'
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      basename = "#{ user }-db-suck-#{ timestamp }"

      src = File.join(deploy_to, 'current/db/dump', basename)
      dst = File.join(rails_root, 'db/dump', basename)
      FileUtils.mkdir_p(dst)

      run("cd #{ deploy_to }/current && ./bin/rake db:dump directory=#{ src }")

      download(src, dst, :recursive => true)

      run_locally("./bin/rake db:load directory=#{ dst }")
    end

    desc 'blow a local database into remote one'
    task :blow, :roles => :db do
      stage = fetch(:stage)
      unless ENV['FORCE']
        abort("not to production!") if stage.to_s =~ /production/
      end

      require 'fileutils'
      rails_root = File.expand_path(File.dirname(__FILE__))
      user = ENV['USER'] || 'cap'
      timestamp = Time.now.strftime('%Y%m%d%H%M%S')
      basename = "#{ user }-db-blow-#{ timestamp }"

      src = File.join(rails_root, 'db/dump', basename)
      dst = File.join(deploy_to, 'current/db/dump', basename)

      run_locally "./bin/rake db:dump directory=#{ src }"

      run("cd #{ deploy_to }/current && ./bin/rake db:dumpdir")
      upload(src, dst, :recursive => true)

      run("cd #{ deploy_to }/current && ./bin/rake db:load directory=#{ dst }")
    end
  end

  namespace :site do
    require 'fileutils'
    desc 'import site content from remote'
    task :import, :roles => :db do
      require 'fileutils'

      rails_root = File.expand_path(File.dirname(__FILE__))
      dst = File.join(rails_root, 'db/site')
      src = File.join(deploy_to, 'current/db/site')
      Dir.chdir(dst) do
        p Dir["*"]
      end
      run "cd #{ deploy_to }/current && ./bin/rake site:export"

      download(src, dst, :recursive => true)

      run_locally "./bin/rake site:import"
    end

    desc 'export local site content to remote'
    task :export, :roles => :db do
      src = File.join(rails_root, 'db/site')
      dst = File.join(deploy_to, 'current/db/site')
      run_locally "./bin/rake site:export"
      run "cd #{ deploy_to }/current && ./bin/rake site:clean"
      Dir.chdir(src) do
        Dir["*"].each do |entry|
          upload(File.join(src,entry), File.join(dst,entry), :recursive => true)
        end
      end
      run "cd #{ deploy_to }/current && ./bin/rake site:import"
    end
  end


## we might have files to put into places...  see rake tasks.
#
  namespace :deploy do
    task :files, :roles => :app do
      stage = fetch(:stage)
      run("cd #{ deploy_to }/current && RAILS_STAGE=#{ stage } bundle exec rake deploy:files; true")
    end
  end
  after 'deploy:create_symlink', 'deploy:files'

## we might have to expand os_files from templates...
#
  namespace :deploy do
    namespace :generate do
      task :os_files, :roles => :app do
        run("cd #{ deploy_to }/current && RAILS_STAGE=#{ stage } bundle exec rake deploy:generate:os_files; true")
      end
    end
  end
  #after 'deploy:create_symlink', 'deploy:generate:os_files'

## for *normal* apache/nginx passenger restarting
#
  namespace :deploy do
    task :start do ; end
    task :stop do ; end
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "#{ try_sudo } touch #{ File.join(current_path,'tmp','restart.txt') }"
    end
  end
  after 'deploy', 'deploy:restart'

## link vhost config
#
  namespace :apache do
    task :enable do
      src = "./config/deploy/os_files/etc/apache2/sites-enabled/#{ stage }.conf"

      #ENV['RAILS_STAGE'] = stage.to_s
      #`bundle exec rake deploy:generate:os_files`

      if test(?s, src)
        dst = "/etc/apache2/sites-enabled/#{ identifier }.#{ stage }"
        tmp = File.join("/tmp", "#{ identifier }.#{ stage }.tmp") 
        upload(src, tmp, :via => :scp)
        run "sudo mv -f #{ tmp.inspect } #{ dst.inspect }"
        run "if sudo apache2ctl configtest 2>&1; then sudo apache2ctl restart; fi; true"
      else
        abort "missing: #{ src }"
      end
    end

    task :restart do
      run "if sudo apache2ctl configtest 2>&1; then sudo apache2ctl restart; fi; true"
    end
  end
  after "apache:enable", "apache:restart"
  #after 'deploy', 'deploy:link_vhost'

## pass-ass-en-ger
#
# uncomment this to use passenger standalone
#
=begin
  namespace :passenger do
    desc "Restart Passenger Standalone"
    task :restart, :roles => :app, :except => { :no_release => true } do
      run "cd #{ deploy_to }/current && ./script/passenger restart production"
    end
  end
  after 'deploy:restart', 'passenger:restart'
=end

## maybe we have background tasks running...
#
  namespace :jobs do
    task :restart do
      run("cd #{ deploy_to }/current && ./script/jobs restart; true")
    end

    task :start do
      run("cd #{ deploy_to }/current && ./script/jobs start; true")
    end

    task :stop do
      run("cd #{ deploy_to }/current && ./script/jobs stop; true")
    end
  end
  before 'deploy:create_symlink', 'jobs:stop'
  after 'deploy', 'jobs:restart'
  after 'deploy:rollback', 'jobs:restart'

## clear the public and app caches after a deploy
#
  namespace :cache do
    task :clear do
      run("cd #{ deploy_to }/current && bundle exec rake cache:clear; true")
    end

    task :warm do
      stage = fetch(:stage)
      url = fetch(:url)
      system "cd /tmp && nohup wget --mirror #{ url } &"
    end
  end
  after "deploy", "cache:clear"
  #after "deploy", "cache:warm"

## hit the app.  if we do not pre-compile assets this request will prime the
# pump
#
  namespace :force do
    task :teh_assets_to_compile do
      url = fetch(:url)
      fork do
        #`nohup curl #{ url.inspect } >/dev/null && open #{ url.inspect }`
        `nohup curl #{ url.inspect } >/dev/null && rm -f nohup.out`
        exit!
      end
    end
  end
  after "deploy", "force:teh_assets_to_compile"


=begin
## deploy assets
#
# uncomment this line to pre-compile assets
#
  load 'deploy/assets'
=end

##
#
  after 'deploy', 'db:mongoid:create_indexes'
  #after 'deploy', 'suggest:db:mongoid:create_indexes'
  namespace :deploy do
    task :indexes do
      deploy
      db.mongoid.create_indexes
    end
  end

## whenever setup
#
  set :whenever_command, "bundle exec whenever"
  #set :whenever_environment, defer { stage }
  set :whenever_identifier, defer { "#{ application }_#{ stage }" }
  #require "whenever/capistrano"
  require 'whenever/capistrano/recipes'
  after 'deploy:create_symlink', 'whenever:update_crontab'
  after 'deploy:rollback', 'whenever:update_crontab'
  # ref: https://github.com/javan/whenever/pull/273


## notify
#
  namespace :notify do
    desc 'alert campfire of a deploy'
    task :campfire do
      user = `git config --global --get user.name 2>/dev/null`.strip
      if user.empty?
        user = ENV['USER']
      end
      git_rev = `git rev-parse HEAD 2>/dev/null`.to_s.strip
      application = fetch(:application)
      stage = fetch(:stage)

      domain = 'dojo4'
      token = 'f9831e567f7237563baa64b90e65a135f223100f'
      room = "Roboto's House of Wonders"

      begin
        require 'tinder'
        campfire = Tinder::Campfire.new(domain, :token => token)
        room = campfire.rooms.detect{|_| _.name == room}
        room.speak("#{ user } deployed #{ application } to #{ stage } @ #{ git_rev }")
      rescue LoadError
        warn "gem install tinder # to notify #{ domain }/#{ room } campfire..."
      end
    end

    desc 'alert stakeholders of a deploy via email'
    task :email do
      App.configure_email(:env => 'production')

      user = `git config --global --get user.name 2>/dev/null`.strip
      if user.empty?
        user = ENV['USER']
      end
      git_rev = `git rev-parse HEAD 2>/dev/null`.to_s.strip
      application = fetch(:application)
      stage = fetch(:stage)

      subject = "#{ user } deployed #{ application } to #{ stage } @ #{ git_rev }"

      emails = Array(fetch(:settings)[:deploy][:notify]) rescue []

      emails.each do |email|
        Mailer.text(email, :subject => subject).deliver
        puts email
      end
    end

    desc 'print the deployed-to url out on the console'
    task :console do
      require 'yaml'
      require 'terminal-notifier'

      url         = fetch(:url)
      application = fetch(:application)
      user        = fetch(:user)
      deploy_to   = fetch(:deploy_to)

      puts({
        'application' => application,
        'url'         => url,
        'user'        => user,
        'deploy_to'   => deploy_to
      }.to_yaml);
      
      system "terminal-notifier -title #{ application } -message 'Deploy completed successfully to #{ url }.' -sound default"
    end
  end
  after "deploy", "notify:campfire"
  after "deploy", "notify:email"
  after "deploy", "notify:console"

  #after "deploy", "deploy:cleanup"


##
#
  namespace :fast do
    task :deploy do
      run "cd #{ current_path } && git pull origin master 2>&1 && { nohup rake cache:clear 2>&1 >/dev/null & } && touch tmp/restart.txt"
    end
  end
  after "fast:deploy", "notify:campfire"
  after "fast:deploy", "notify:email"
  after "fast:deploy", "notify:console"

