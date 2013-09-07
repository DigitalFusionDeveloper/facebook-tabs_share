namespace :deploy do

  task :files => :environment do
    if Rails.stage
      prefix = File.join(Rails.root, 'config/deploy/files', Rails.stage)
      glob = File.join(prefix, '**/**')

      Dir.glob(glob) do |entry|
        src = entry
        dst = Pathname.new(src).relative_path_from(Pathname.new(prefix)).to_s
        dirname, basename = File.split(dst)
        next if basename == '.gitkeep'
        next if test(?d, src)

        FileUtils.mkdir_p(dirname.to_s)
        FileUtils.copy_entry(src.to_s, dst.to_s)
        p src.to_s => dst.to_s
      end
    end
  end

  namespace :generate do
    task :os_files do
      prefix = File.join(Rails.root, 'config/deploy/os_files')
      glob = File.join(prefix, '**/**')

      Dir.glob(glob) do |entry|
        next if test(?d, entry)
        src = entry
        re = /\.(erb|eruby|tmpl)\Z/

        if src =~ re
          Rake::Task['environment'].invoke unless defined?(Rails.environment)
          template = src
          src = template.gsub(re, '')
          erb = IO.read(template)
          content = ERB.new(erb).result(TOPLEVEL_BINDING)
          open(src, 'w'){|f| f.write(content)}
          puts "#{ template } #=> #{ src }"
        else
          next
        end
      end
    end
  end

end
