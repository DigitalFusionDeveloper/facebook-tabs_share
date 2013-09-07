## use this for debugging smtp connection errors
#
  if ENV['SMTP_DEBUG']
    class Net::SMTP
      Initialize = instance_method(:initialize)

      def initialize(*args, &block)
        Initialize.bind(self).call(*args, &block)
      ensure
        @debug_output = STDERR
      end
    end
  end
