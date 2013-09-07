module App
  module Document
    code_for 'app/document/logger' do
      def self.loggers
        @loggers ||= []
      end

      def self.push_logger(*args, &block)
        args.push(STDERR) if args.empty?
        logger = Logger.new(*args)
        loggers.push(logger)
        ::Mongoid.logger = logger
        if block
          begin
            block.call()
          ensure
            loggers.pop()
          end
        else
          logger
        end
      end

      def self.pop_logger
        logger = loggers.pop
        ::Mongoid.logger = loggers.last
        logger
      end

      def self.logging(*args, &block)
        push_logger(*args, &block)
      end

      %w( loggers push_logger pop_logger logging ).each do |m|
        module_eval <<-__
          def #{ m }(*args, &block)
            self.class.#{ m }(*args, &block)
          end
        __
      end
    end
  end
end
