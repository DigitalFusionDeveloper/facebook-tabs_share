### require 'config/capistrano_database_yml'
#
stage = fetch(:stage)
identifier = fetch(:identifier)
repository = fetch(:repository)

set :application, identifier
set :user, "dojo4"
set :deploy_to, "/ebs/apps/#{ identifier }.#{ stage }"

set :scm, :git
set :deploy_via, :remote_cache

# be sure to run 'ssh-add' on your local machine
system "ssh-add 2>&1" unless ENV['NO_SSH_ADD']
ssh_options[:forward_agent] = true

set :deploy_via, :remote_cache
set :branch, "master" unless exists?(:branch)
set :use_sudo, false

ip = "p0.dojo4.com"
role :web, ip                          # Your HTTP server, Apache/etc
role :app, ip                          # This may be the same as your `Web` server
role :db,  ip, :primary => true # This is where Rails migrations will run

set(:url, url)
