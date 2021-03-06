# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

every 15.minutes do
  rake 'jobs:run'
  #rake 'upload:process:all'
  script 'locate_all_locations'
end

every 1.day do
  runner 'Job.failure.limit(1024).each{|job| job.run}'
  rake 'jobs:clear'

  rake 'logs:rotate'
  rake 'tmp:uploads:clear'
end

every 1.week do
  runner 'JavascriptJob.complete.destroy_all'
end
