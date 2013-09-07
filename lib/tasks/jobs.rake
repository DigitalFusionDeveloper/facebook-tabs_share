namespace :jobs do
  task :clear => :environment do
    before = Job.count
    Job.clear
    after = Job.count
    puts(before - after)
  end

  task :run do
    Dir.chdir(File.dirname(File.dirname(File.dirname(__FILE__)))) do
      exec './script/jobs run'
    end
  end

  task :work do
    Dir.chdir(File.dirname(File.dirname(File.dirname(__FILE__)))) do
      exec './script/jobs run'
    end
  end

  task :start do
    Dir.chdir(File.dirname(File.dirname(File.dirname(__FILE__)))) do
      exec './script/jobs start'
    end
  end

  task :stop do
    Dir.chdir(File.dirname(File.dirname(File.dirname(__FILE__)))) do
      exec './script/jobs stop'
    end
  end
end
