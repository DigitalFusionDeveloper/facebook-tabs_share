App = Module.new

App.singleton_class.module_eval do
# app settings
#
  fattr(:settings){ Map.for(Settings.for(File.join(Rails.root, 'config/app.yml'))) }
  fattr(:ses_smtp_settings){ Map.for(Settings.for(File.join(Rails.root, 'config/ses_smtp.yml'))) }
  fattr(:identifier){ settings.identifier.to_s }
  fattr(:prefix){ [App.identifier, Rails.stage || Rails.env].join('_') } 
  fattr(:secret_token){ settings.secret_token.to_s }
  fattr(:geonames_settings){ Map.for(( Settings.for(File.join(Rails.root, 'config/geonames.yml')) rescue {'username' => 'demo'} )) }
  fattr(:sekrets){ Sekrets.settings_for(File.join(Rails.root, 'config', 'sekrets.yml.enc')) } 

# conf
#
  fattr(:underscore){ identifier.to_s.underscore }
  fattr(:slug){ Slug.for(identifier) }
  fattr(:title){ underscore.to_s.titleize }

  %w( protocol host port ).each do |attr|
    eval <<-__
      def #{ attr }
        DefaultUrlOptions.#{ attr }
      end

      def #{ attr }=(value)
        DefaultUrlOptions[:#{ attr }] = value
      end
    __
  end

  def domain
    @domain || (
      case host
        when '0.0.0.0'
          'localhost'
        when /\A[\d.]+\Z/iomx
          host
        else
          host.split('.').last(2).join('.')
      end
    )
  end

  def domain=(value)
    @domain = value
  end

# This is the default vaild testing email for rails_app_m
#  AWS SES will accept this email by default with the dojo4 testing creds
#
  fattr(:email){ ses_smtp_settings.email }

  fattr(:logger){ Rails.logger }

  fattr(:dangerous){ !Rails.stage }

# templates
#
  fattr(:templates){
    if Template.cache.blank?
      Template.load_file('app/views/shared/_templates')
    end
    Template.cache
  }

# shortcut to run a rake task: App.task('db:seed').execute
#
  def App.task(k)
    load(File.join(Rails.root, 'Rakefile')) unless defined?(Rake)
    @tasks ||= {}
    @tasks[k.to_s] ||= Rake::Task[k.to_s]
  end

  def App.rake!(task, *args, &block)
    require 'rake' unless defined?(Rake)
        
    $stdout = StringIO.new
    $stderr = StringIO.new
  
    stdout = nil
    stderr = nil
    error = nil
      
    begin
      Rake.application.clear
      Rake.application.load(Rails.root.join('Rakefile').to_s)
      Rake.application[task].invoke(*args)
    rescue Object => e
      error = e
    ensure
      stdout = $stdout.string
      stderr = $stderr.string
      $stdout = STDOUT
      $stderr = STDERR
    end 
      
    [stdout, stderr, error]
  end

# encryption/encoding support
#
  def App.encrypt(plaintext, options = {})
    ciphertext = Encryptor.encrypt(plaintext, options)
    encodedtext = Encoder.encode(ciphertext)
  end

  def App.decrypt(encodedtext, options = {})
    ciphertext = Encoder.decode(encodedtext)
    plaintext = Encryptor.decrypt(ciphertext, options)
  end

  def App.recrypt(plaintext, options = {})
    decrypt(encrypt(plaintext, options), options)
  end

  def App.encode(plaintext)
    encodedtext = Encoder.encode(plaintext)
  end

  def App.decode(encodedtext)
    plaintext = Encoder.decode(encodedtext)
  end

  def App.recode(plaintext)
    decode(encode(plaintext))
  end

# uuid generation
#
  def App.uuid(*args)
    # UUIDTools::UUID.timestamp_create.to_s  ### gem install uuidtools
    # UUID.generate ### gem install uuid
      FFI::UUID.generate_time.to_s  ### gem install ffi-uuid 
  end

# domid generation
#
  def App.domid(*args)
    args.flatten!
    args.compact!
    args.push('app') if args.empty?
    args.push(App.uuid)
    args.join('-')
  end

# server info support
#
  ServerInfo = {
  }
  def App.server_info
    if ServerInfo.blank? 
      ServerInfo.update({
        'hostname' => Socket.gethostname.strip,
        'git_rev' => `git rev-parse HEAD 2>/dev/null`.to_s.strip,
        'rails_env' => Rails.env,
        'rails_stage' => Rails.stage
      })
      ServerInfo.update(current_controller.send(:params).slice(:controller, :action))
      ServerInfo[:database] = Mongoid.database.name if defined?(Mongoid.database.name)
    end
    ServerInfo
  rescue
    {}
  end
 
  # For some reason, the first call doesn't always get a 
  # populated hash...
  def App.git_rev
    server_info['git_rev'] || server_info['git_rev']
  end

  def App.git_short_rev
    git_rev[0...7]
  end

# support for rails independent url generation. useful in mailers, background jobs, etc.
#
  def App.slash(options = {})
    options = options.to_options!

    protocol = options.has_key?(:protocol) ? options[:protocol] : App.protocol
    host = options.has_key?(:host) ? options[:host] : App.host
    port = options.has_key?(:port) ? options[:port] : App.port

    slash = []
    if protocol and host
      protocol = protocol.to_s.split(/:/, 2).first 
      slash << protocol
      slash << "://#{ host }"
    else
      slash << "//#{ host }"
    end
    if port
      slash << ":#{ port }"
    end
    slash.join
  end

  def App.url(*args)
    options = args.extract_options!.to_options!

    path_info = options.delete(:path_info) || options.delete(:path)
    query_string = options.delete(:query_string)
    fragment = options.delete(:fragment) || options.delete(:hash)
    query = options.delete(:query) || options.delete(:params)

    raise(ArgumentError, 'both of query and query_string') if query and query_string

    args.push(path_info) if path_info
    slash = App.slash(options).sub(%r|/*$|,'')
    url = slash + ('/' + args.join('/')).gsub(%r|/+|,'/')

    url += ('?' + query_string) unless query_string.blank?
    url += ('?' + query.query_string) unless query.blank?
    url += ('#' + fragment) if fragment
    url
  end

  def App.url_for(*args, &block)
    helper.url_for(*args, &block)
  end

  def App.helper
    Helper.new(Current.controller)
  end

  def App.json_for(object, options = {})
    object = object.as_json if object.respond_to?(:as_json)

    options.to_options!
    options[:pretty] = json_pretty?  unless options.has_key?(:pretty)

    begin
      MultiJson.dump(object, options)
    rescue Object => e
      YAML.load( object.to_yaml ).to_json
    end
  end

  def App.json_pretty?
    @json_pretty ||= (defined?(Rails) ? !Rails.env.production? : true)
  end

  def App.parse_json(*args, &block)
    MultiJson.load(*args, &block)
  end

  def App.token_for(options = {})
    case options
      when Hash
        App.create_token(options)
      else
        App.parse_token(options.to_s)
    end
  end

# simple encrypted token support
#
  def App.token(*args, &block)
    App.token_for(*args, &block)
  end

  def App.create_token(*args)
    options = args.extract_options!.to_options!
    data = args.first || options[:data] || rand
    expires = options[:expires]

    if expires
      expires = Time.parse(expires.to_s)
      now = Time.now
      expired = (expires ? now > expires : false)
      expires = expires.iso8601
    else
      expired = false
    end

    hash = {}
    hash['data'] = data
    hash['expires'] = expires

    json = App.json_for(hash)
    token = App.encode(json)

    token.fattr(:data => data)
    token.fattr(:expires => expires)
    token.fattr(:expired => expired)
    token.fattr(:valid){ !expired }

    token
  end

  def App.parse_token(token)
    token.to_s.tap do |token|
      token.fattr(:data => nil)
      token.fattr(:expires => nil)
      token.fattr(:expired => true)
      token.fattr(:valid){ !expired }

      unless token.blank?
        now = Time.now

        begin
          json = App.decode(token)
          hash = App.parse_json(json)

          token.data = hash['data']

          if expires = hash['expires']
            token.expires = Time.parse(expires)
            token.expired = (now > token.expires)
          else
            token.expires = nil
            token.expired = false
          end

          token.valid = !token.expired
        rescue
          nil
        end
      end
    end
  end

  def App.token?(token)
    App.parse_token(token).valid?
  rescue
    nil
  end

  def App.settings_for(*args, &block)
    settings = Settings.for(*args, &block)
    Map.new( settings[Rails.env] || settings )
  end

  def App.db_names
    result =
      Mongoid.session(:default).
        with(database: :admin).
          command({listDatabases:1})

    result['databases'].map{|hash| hash['name']}
  end

  def App.db_name
     Mongoid::Sessions.default.send(:current_database).name
  end

  def App.db_collections
    Mongoid::Sessions.default.collections
  end

  def App.db_snapshot
    $db_collections = Map.new
    db_collections.each do |collection|
      name = collection.name
      next if name =~ /\bsystem\b|\$/
      documents = collection.find().to_a
      unless documents.blank?
        $db_collections[name] = documents
      end
    end
    $db_collections
  end

  def App.db_restore(snapshot = $db_collections)
    collections = db_collections

    (snapshot || Map.new).each do |name, documents|
      collection = collections.detect{|collection| collection.name == name}
      unless collection.blank? or documents.blank?
        collection.drop
        documents.each{|document| collection.insert(document)}
      end
    end
  end

  def App.db_enable_text_search!
    session = Mongoid::Sessions.default
    session.with(database: :admin).command({ setParameter: 1, textSearchEnabled: true })
  end

# this method method will return true if it appears your rail's app is running
# in a cap deployment.  given a block, it will run that block only if the app
# has been deployed via cap
#
  def App.cap?(&block)
    realpath = proc do |path|
      begin
        (path.is_a?(Pathname) ? path : Pathname.new(path.to_s)).realpath.to_s
      rescue Errno::ENOENT
        nil
      end
    end

    rails_root = realpath[Rails.root]

    shared_path = File.expand_path('../../shared', rails_root)
    cap_path = File.dirname(shared_path)
    shared_public_system_path = File.expand_path('../../shared/system')

    public_path = Rails.public_path.to_s
    public_system_path = File.join(Rails.public_path.to_s, 'system')
 
    is_cap_deploy =
      test(?e, shared_public_system_path) and
      test(?l, public_system_path) and
      realpath[shared_public_system_path] == realpath[public_system_path]

    return false unless is_cap_deploy

    block ? block.call(*[cap_path].slice(0, block.arity)) : cap_path
  end

# true in the console
#
  def App.console?(&block)
    is_console = STDIN.tty? || defined?(Rails::Console)
    is_console ? block ? block.call() : true : false
  end

# redis connection
#
  def App.redis
    @redis ||= (
      namespace = App.redis_namespace
      config = App.redis_config

      Redis::Namespace.new(namespace, :redis => Redis.new(config))
    )
  end

  def App.redis_namespace
    [App.identifier, Rails.stage || Rails.env, App.git_short_rev].join(':')
  end

  def App.redis_config
    config = {}

    sockets = %w[ /var/run/redis/redis.sock /tmp/redis.sock ]

    sockets.each do |socket|
      if test(?r, socket)
        config[:path] = socket
      end
    end

    config
  end

  def App.redis_store_config
    redis_config.
      merge(:namespace => App.redis_namespace).
      merge(:expires_in => 42.years)
  end

## all routes in teh applicaiton eaten by config/routes.rb, public/*,
# +blacklisted routes
#
  def App.reserved_routes
    @reserved_routes ||= (
      anything_in_public =
        Dir[File.join(Rails.root, "public/*")].map {|file| File.basename(file)}

      begin
        route_prefixes =
          Rails.application.routes.routes.
            map{|route| route.path.spec.to_s}.
            map{|path| path[%r|[^/)(.:]+|]}.
            compact.sort.uniq
      rescue Object => e
        #warn "#{ e.message }(#{ e.class }) :#{ __FILE__ }:#{ __LINE__ }"
        #route_prefixes = []
        raise
      end

      blacklist = %w[
        index
        new
        create
        update
        show
        delete
        destroy
        ajax
        call
        callback
      ]

      basenames = (
        anything_in_public +
        route_prefixes +
        blacklist
      ).map{|_| File.basename(_)}

      (
        basenames +
        basenames.map{|basename| basename.split('.', 2).first}
      ).sort.uniq
    )
  end

##
#
  def App.clear_public_cache!(*args)
    options = Map.options_for!(args) 
    args.flatten!
    args.compact!
    args.push('.') if args.blank?

    output = []
    paths = []

    Dir.chdir(Rails.public_path) do
      args.each do |path|
        path = File.expand_path("./#{ path }")
        next unless test(?e, path)
        command = "git clean -d -f -x -e system #{ options[:noop] && '-n' } #{ Rails.public_path.inspect } 2>&1"

        if options[:noop]
          output << command
        end

        oe = `#{ command }`

        if options[:noop]
          output << oe
        end

        paths.push(path)
      end
    end

    options[:noop] ? output.join("\n") : paths
  end

  def App.clear_cache!(*args)
    Rails.cache.clear
    App.clear_public_cache!(*args)
    Rails.cache
  end
end

load File.join(Rails.root, 'lib/app/config.rb')
load File.join(Rails.root, 'lib/app/document.rb')
load File.join(Rails.root, 'lib/app/conducer.rb')
#load File.join(Rails.root, 'lib/app/transaction.rb')
