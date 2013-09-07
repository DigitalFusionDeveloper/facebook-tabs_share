#!/usr/bin/env rake
## ensure we're running under 'bundle exec'
#
  unless ENV['BUNDLE_GEMFILE']
    command = "bundle exec rake #{ ARGV.join(' ') }"
    exec(command)
  end

# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

Dojo4::Application.load_tasks
