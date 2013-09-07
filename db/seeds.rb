## load dem seeds
#
  if ENV['SEED']
    Kernel.load(ENV['SEED'])  
  else
    load_seeds!
  end
  run_seeds!


BEGIN {
  STDOUT.sync = true
  STDERR.sync = true

  module Kernel
  private
    def dangerous_seeds 
      App.dangerous?
    end
    alias_method('dangerous_seeds?', 'dangerous_seeds')

    def seed(name, *args, &block)
      options = args.extract_options!.to_options!
      @seeds ||= []
      path = eval('__FILE__', block.binding)

      guard = compile_guard(options)

      @seeds.push([name, path, block, guard])
    end

    def compile_guard(options)
      [:guard, :unless, :if].each do |key|
        next unless options.has_key?(key)
        value = options[key]

        guard =
          if value.respond_to?(:call)
            proc{ !!value.call() }
          else
            proc{ !!value }
          end

        return(key == :if ? proc{ !guard.call() } : guard)
      end
      nil
    end


    def run_seeds!
      @seeds ||= []
      @seeds.each do |seed|
        name, path, block, guard, *ignored = seed
        skip = guard ? guard.call() : false
        #puts("db:seed #=> #{ path } #{ name.inspect }#{ ' (skipped)' if skip }")
        unless skip or ENV['QUIET']
          puts("db:seed #=> #{ path } #{ name.inspect }")
        end
        transactionally{ block.call() } unless skip
      end
    end

    def transactionally(*args, &block)
      defined?(transaction) ? transaction(*args, &block) : block.call()
    end

    def environments
      @environments ||= (
        envs = %w( RAILS_SEEDS SEEDS RAILS_SEED SEED ).map{|k| ENV[k]}.compact
        envs = [Rails.env] if envs.empty?
        envs.map{|env| env.strip.split(/\s*,\s*/)}.flatten.compact
      )
    end

    def load_seeds!
      load_dir_seeds!('boot')

      environments.each do |env|
        load_dir_seeds!(env)
      end

      load_dir_seeds!('all')
    end

    def load_dir_seeds!(which)
      seed = File.join(Rails.root, "db", "seeds", "#{ which }.rb")
      seeds = File.join(Rails.root, "db", "seeds", "#{ which }/**/**.rb")

      entries = [seed] + Dir.glob(seeds).sort

      entries.each do |entry|
        next unless test(?s, entry)
        entry = File.expand_path(entry)
        Kernel.load(entry)
      end
    end
  end
}
