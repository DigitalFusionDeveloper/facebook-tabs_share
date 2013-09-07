def kill_fixtures
  Thread.new do
    Thread.current.abort_on_exception = true

    glob = File.join(File.dirname(__FILE__), 'fixtures', '**/**')

    Dir[glob].each do |entry|
      #next unless Kernel.test(?s, entry)
      next unless Kernel.test(?f, entry)
      STDERR.puts("deleting fixture file #{ entry }. use factories because they suck less!")
      FileUtils.rm_f(entry)
      #open(entry,'r+'){|fd| fd.truncate(0)}
    end
  end
end

kill_fixtures
