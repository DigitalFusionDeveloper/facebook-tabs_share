#
# this module encapsulate the interface expected by DelayedJob, and Resque -
# if you use it your app will not need to change if you change background
# processing systems.  it also centralizes and makes easy to test all
# potential background jobs independently of your preferred system.
#
# all jobs are stored in the db, but a queueing system, like resque, is used
# to run them in the background.  this way the job class can support a rich
# query interface and persistence regardless of the background processing
# system used.
#
# examples:
#
#   Job.submit(Mailer, :invitation, 'ara@dojo4.com')
#
#   Job.submit('p :this_is_evaled')
#
#   Job.submit(CustomJob, :method_to_run, :arbitrary, :args => :to_pass)
#
#   Job.submit(RespondsTo_perform, :arbitrary, :args => :to_pass)
#
#   Job.pending.count
#
#   Job.clear  # you'll wanna run this using whenever or something...
#
  class Job
  ##
  #
    include App::Document

    field(:object, :type => String, :default => proc{ 'Scope' })
    field(:message, :type => String, :default => proc{ 'eval' })
    field(:args, :type => Array, :default => proc{ [] })

    field(:status, :type => String, :default => 'pending')
    field(:result)
    field(:starts_at, :type => Time, :default => proc{ Time.now.utc })
    field(:started_at, :type => Time)
    field(:completed_at, :type => Time)
    field(:attempts, :type => Integer, :default => proc{ 0 })

    field(:runner)

    %w( pending running success failure ).each do |status|
      scope(status, where(:status => status))
    end

  ##
  #
    class Failure
      include App::Document::Embedded

      field(:type, :type => String)
      field(:message, :type => String)
      field(:backtrace, :type => Array)

      def Failure.for(failure)
        case failure
          when Failure
            failure
          when Hash
            new(failure.to_options.slice(:message, :type, :backtrace))
          when String, Symbol
            new(:message => failure.to_s)
          else
            raise(ArgumentError, failure.class)
        end
      end

      before_validation do |failure|
        unless failure.message.blank?
          failure.message = failure.message.to_s
        end

        unless failure.type.blank?
          failure.type = failure.type.to_s
        end

        unless failure.backtrace.blank?
          failure.backtrace = Array(failure.backtrace).flatten.compact
        end
      end

      embedded_in(:job, :class_name => '::Job')
    end
    embeds_many(:failures, :class_name => '::Job::Failure')

    def failures?
      !failures.blank?
    end

    def failure
      failures.last
    end

    def failure=(failure)
      failures.push(Failure.for(failure))
    end

  ##
  #
    def Job.background
      unless defined?(@background)
        Job.background = (
          Rails.env.production? or ENV['RAILS_BACKGROUND_JOBS']
        )
      end
      @background
    end

    def Job.background?
      background
    end

    def Job.background=(value)
      @background = !!value
    end

    def Job.foreground?
      !background?
    end

    def Job.runner
      Slug.for(:job, :runner, Socket.gethostname, Process.ppid, Process.pid, Thread.current.object_id.abs)
    end

    Fattr(:max_attempts){ 16 }

    def Job.run(&block)
    # setup
    #
      Job.clear


    # now run 'em - new jobs first.  old shitty jobs next
    #
      jobs = []

      loop do
        try_again =
          false

        runner =
          Job.runner

        hung =
          1.hour.ago.utc

        max_attempts =
          Job.max_attempts

        starts_at =
          (Time.now + 1).utc

        conditions = [
          { :runner.in     => [nil, runner], :completed_at => nil, :attempts.lt => 1},
          { :runner.in     => [nil, runner], :completed_at => nil, :attempts.lt => max_attempts},
          { :started_at.lt => hung,          :completed_at => nil, :attempts.lt => max_attempts},
          { :created_at.lt => hung,          :completed_at => nil, :attempts.lt => max_attempts}
        ]

        conditions.any? do |condition|
          query =
            where(condition).or({:starts_at => nil}, {:starts_at.lte => starts_at}).
              order_by([[:created_at, :asc], [:attempts, :asc]])

          job =
            query.find_and_modify(
              {
                '$set' => {:status => 'running', :started_at => Time.now.utc, :runner => runner},
                '$inc' => {:attempts => 1}
              },
              {'new' => true}
            )

          if job
            try_again = true

            block.call(job) if block

            job.run(:reserved => true)

            block.call(job) if block

            jobs.push(job) unless block
          end
        end

        break unless try_again
      end

      block ? nil : jobs
    end

    def run(options = {})
      job = self

      options = options.to_options!

      unless options[:reserved]
        Job.where(:id => id).find_and_modify(
          '$set' => { :status => 'running', :started_at => Time.now.utc, :runner => Job.runner },
          '$inc' => {:attempts => 1}
        )
      end

      n = 0
      retries = 1

      begin
        n += 1

        object = Job.eval(read_attribute(:object))

        result =
          case
            when object <= ActionMailer::Base
              mailer = object
              mail = mailer.send(:new, message, *args).message
              mail.deliver
              Array(mail.destinations)
            else
              object.send(message, *args)
          end

        Job.where(:id => id).find_and_modify(
          '$set' => {
            'status'       => 'success',
            'completed_at' => Time.now.utc,
            'result'       => Job.pod(result)
          }
        )
      rescue Object => e
        # Rails.logger.error("JOB=#{ id } #{ e.message } (#{ e.class.name })\n#{ Array(e.backtrace).join(10.chr) }")

        if n <= retries
          sleep(rand)
          retry
        end

        job       = reload
        now       = Time.now.utc

        if Rails.env.production?
          exponent  = [job.attempts - 1, 6].min
          delay     = (2 ** exponent).minutes
          starts_at = now + delay
        else
          starts_at = job.starts_at || now
        end

        failure = {
          '_id'       => Moped::BSON::ObjectId.new,
          'type'      => e.class.name,
          'message'   => e.message.to_s,
          'backtrace' => Array(e.backtrace),
          'created_at' => now,
          'updated_at' => now
        }

        Job.where(:id => id).find_and_modify(
          '$set' => {
            'status'       => 'failure',
            'completed_at' => nil,
            'result'       => nil,
            'starts_at'    => starts_at
          },

          '$push' => {
            'failures' => failure
          }
        )
      end

      job.reload
    end

    def Job.pod(value)
      pod =
        begin
          case value
            when Hash, Array
              MultiJson.load(MultiJson.dump(value))
            else
              {'_' => MultiJson.load(MultiJson.dump(value))}
          end
        rescue Exception, Object
          {'_' => value.class.name}
        end

      pod = pod.is_a?(Hash) ? undotify(pod) : pod
    end

    def Job.undotify(hash = {}, accum = {})
      hash.each do |k, v|
        if k.to_s.include?('.')
          k = k.to_s.gsub('.', '-')
        end

        accum[k] = v.is_a?(Hash) ? undotify(v) : v
      end

      accum
    end

    def Job.submit(*args, &block)
      job =
        case args.size
          when 0
            raise ArgumentError
          when 1
            create!(:object => Scope, :message => :eval, :args => args)
          else
            object = object_for(args.shift)
            message = (args.shift || :perform).to_s
            create!(:object => object, :message => message, :args => args)
        end

=begin
    # needed for redis/resque...

      begin
        enqueue(job)
      rescue Object => e
        job.destroy
        raise SubmitError
      end
=end

      if Job.background?
        Job.ping
      else
        job.run
      end

      job
    end

    def Job.script
      File.join(Rails.root, 'script', 'jobs')
    end

    def Job.ping
      signaled = false

      pid_file = Rails.root.join('log/background/jobs/pid').to_s
      pid = Integer(IO.read(pid_file)) rescue nil

      if pid
        begin
          Process.kill('SIGALRM', pid)
          signaled = true
        rescue Object
          nil
        end
      end

      unless signaled
        `nohup #{ Job.script } ping >/dev/null 2>&1`
      end
    end

    def Job.object_for(value)
      value.to_s
    end

    def Job.eval(code)
      Scope.eval(code)
    end

    def Job.clear(max = 8192)
      if Job.count > max
        where(:status => 'success', :completed_at.lt => 1.minute.ago).
          delete_all
      end

      if Job.count > max
        where(:attempts.gt => 4).
          delete_all
      end

      #where(:completed_at.lt => 1.week.ago).
      #  delete_all
    end

  ## resque support
  #
    @queue = 'jobs'

    def Job.enqueue(job)
      Resque.enqueue(Job, job.id.to_s)
    end

    def enqueue
      Job.enqueue(job=self)
    end

    def Job.dequeue(job)
      raise NotImplementedError
    end

    def dequeue
      Job.dequeue(job=self)
    end

    def Job.perform(id)
      Job.find(id).run
    end

    if defined?(UUID)
      unless ::UUID.respond_to?(:generate)
        class << ::UUID
          def generate(*args) ::App.uuid end
        end
      end
    end

  ## provides a clean scope for evaling code in
  #
    class Scope
      alias_method :__binding__, :binding
      public :__binding__

      instance_methods.each{|m| undef_method m unless m =~ /__|object_id/}

      def Scope.eval(string)
        scope = new
        ::Kernel.eval(string.to_s, scope.__binding__)
      end
    end

  ## error classes
  #
    class SubmitError < ::StandardError
    end
  end
