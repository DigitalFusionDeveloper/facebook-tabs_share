# file: RAILS_ROOT/env.rb
#
# first, we fold in any environment settings found in 
#
#   RAILS_ROOT/env.yml
#
# being careful not to clobber any manually set ENV vars.  the env.yml file is
# normally created during a cap deployment.
#
  require 'erb'
  require 'yaml'
  require 'rbconfig'

  env_yml = File.expand_path('../env.yml', __FILE__)

  if test(?s, env_yml)
    buf = IO.read(env_yml)
    expanded = ERB.new(buf).result(binding)
    config = YAML.load(expanded)
    config.each{|key, val| ENV[key.to_s] ||= val.to_s} if config.is_a?(Hash)
  end

# if a specific ruby has been specified, we are not running it, and REXEC has
# been specified, do crazy reexec shit.  this is *only* relevant in unicorn
# type deploys...
#
  ruby = ENV['APP_RUBY']
  rexec = ENV['APP_REXEC']

  rb = rb_config = ::RbConfig::CONFIG
  actual_ruby = File.join(rb['bindir'], rb['ruby_install_name']) << rb['EXEEXT']

  if((ruby and rexec) and (ruby != actual_ruby))
    warn("replacing sucky ruby #{ actual_ruby } with #{ ruby } ...")
    argv = [ruby, rexec, *ARGV].join(' ')
    exec(argv)
  end

# if a ruby version has been specified puke if it's wrong
#
  ruby_version = ENV['APP_RUBY_VERSION']

  if ruby_version and RUBY_VERSION < ruby_version
    abort("you need ruby #{ ruby_version } or higher for this app")
  end

# ensure that ruby's bin path is inherited by the application for 'system' and
# backtick hygiene
#
  bindir = rb_config['bindir']
  path = ENV['PATH']
  ENV['PATH'] = "#{ bindir }:#{ path }"

# ensure RAILS_* are set
#
  ENV['RAILS_ENV'] ||= 'development'
  ENV['RAILS_ROOT'] ||= File.dirname(File.dirname(__FILE__))

# set Imagick Magick environment
#
# ref: http://www.imagemagick.org/script/resources.php
#
# use system "convert -list resource" in the console to view
#
# realize that these settings are *per-process* so multiple times the number
# of app servers you have running!
#
  tmp = File.join(ENV['RAILS_ROOT'], 'tmp')

# keep your temp files out of system space, which on AWS is part of the root
# volume!
#
  ENV['TMPDIR']              = tmp
  ENV['MAGICK_TMPDIR']       = tmp

=begin

# keep only this many open file handles at a time
#
  ENV['MAGICK_FILE_LIMIT']   = '64'

# width * height < this value fits in memory.  otherwise it uses the pixel
# cache
#
  ENV['MAGICK_AREA_LIMIT']   = '64MB'

# don't eat more than this much memory
#
  ENV['MAGICK_MEMORY_LIMIT'] = '256MiB'

# don't map more than this much memory
#
  ENV['MAGICK_MAP_LIMIT']    = '1GiB'

# eat less than this much disk total
#
  ENV['MAGICK_DISK_LIMIT']   = '64GiB'

# 8 minutes out to be long to enough to re-size a damn image...
#
  ENV['MAGICK_TIME_LIMIT'] = (8 * 60).to_s

=end


# handle compound RAILS_ENV:RAILS_STAGE settings (ie. production_staging or production:staging).
#
  parts = (ENV['RAILS_ENV'] || 'development').to_s.split(%r/[._:-]+/)
  if parts.size > 1
    rails_env = parts.shift
    rails_stage = parts.shift
    ENV['RAILS_ENV'] = rails_env
    ENV['RAILS_STAGE'] ||= rails_stage
    abort('conflicting RAILS_STAGE setting') unless ENV['RAILS_STAGE'] == rails_stage
  end

# set the app version based on git-sha: this'll select the correct cache set
#
  ENV['RAILS_APP_VERSION']=`git rev-parse HEAD`.chomp

