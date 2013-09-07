Setup
=====

Homebrew & Git
--------------
  * Setup Homebrew: http://mxcl.github.com/homebrew/
  * >brew install git
  * >git clone git@github.com:the_account/the_app.git

Ruby
----
  * Setup rbenv: https://github.com/sstephenson/rbenv/
  * Setup ruby-build: https://github.com/sstephenson/ruby-build
  * > rbenv install 1.9.3-p0 && rbenv global 1.9.3-p0 && rbenv rehash
  * > gem install bundler && rbenv rehash

Mongodb, Redis
-----------------------------
  * > brew install mongodb
  * > brew install redis

Install Dependent Gems
----------------------
  * > cd /path/to/your/local/repository
  * > bundle install

Add ./vendor/bundle/bin to your $PATH
-------------------------------------
  * > echo 'export PATH="./vendor/bundle/bin:$PATH"' >> ~/.bash_profile

Setup initial db, test, launch local server
-------------------------------------------
  * > cd /path/to/your/local/repository
  * > ./bin/rake db:bounce
  * > ./bin/rake test
  * > ./bin/rails s


Configure the app
-----------------
  * ./bin/rake app:secret_token
  * vim ./config/app.yml

Deploy the app
--------------
  * first time
    * cap staging deploy:setup
    * cap staging deploy
    * cap staging db:bounce
    * cap staging apache:enable
    * cap staging apache:restart
  * subsequently
    * cap staging deploy

Features
========

  * app settings like secret_token and identifier in config/app.yml

      you can make a new token with SecureRandom.hex(64)

  * env support via env.rb/env.yml deplyments can force complex env setups
    usings this

  * Rails.stage support

  * teh mongodb

  * sane .gitignore

  * .rvmrc and .rbenv-version

  * sane bundler strategy .bundle/config is included, but nuked during
    deployment to keep dev boxen clean

  * a shit ton of important libs, gems and others.  see lib/ and Gemfile

  * the awesome logging gem so you don't filla your disk.  with a sane config.

  * and auto-matic and sane pre-commit hook that is in version control

  * app is setup to upload and serve images from mongo's grid_fs using
    carrierwave

  * application secret token is configurable in config/secret_token.txt, and a
    rake task for adjusting it.

  * rails_nav gem to support multiple names nav elements

  * rails_default_url_options to support correct urls in mailers, background
    jobs, etc.

  * ./sekrets/editor to keep your application secrets in revision control.
    the initial passphrase is set to '^dojo4$' - run ./sekrets/editor --help
    for usage instructions

  * solid geolocation support in app/models/location.rb.
    Location.for('boulder, co')
    Note: create account at geonames.org and update lib/app.rb

  * generic keyword search.  see app/models/search.rb

  * generic token model.  used to generate urls with uuids that reference
    balls of data.  see app/models/token.rb

  * solid user model with embedded roles (makes acl checks much faster), root
    support, and support for auth by email/password, etc

  * support of user membership in any kind of object.

      class Project include App::Document include Shared(:memberships) end

      project.add_member!(user, :admin)

  * much mo betta db/seeds.rb

  * transactions and model tracking.  even with mongo.

  * simple robust backgrounding of mail and arbitrary jobs

  * loaded application controller

  * test controller

  * bootstrap css/js/html framework baked in.

  * dao api support

  * /su area

  * /dashaboard area

  * some sane nav

  * carrierwave w/grid_fs storage

  * mustache templastes in ruby and js alike from same srcs

  * deployment that works outta the box

  * email that works outta the box
  
  * sane config in lib/app.rb (needs tweaked)

  * sane config in config/initializers/default_url_options.r (needs tweaked)

  * app.yml for some quasi static app config

  * test harness that manages having a sane db config between tests
 
