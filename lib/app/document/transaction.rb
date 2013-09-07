module App
  module Document
    @@tracked = []

    def self.tracking(*models, &block)
      models.flatten!
      models.compact!

      previously = {}

      models.replace(self.models) if models.empty?

      models.each do |model|
        previously[model] = model.tracking?
        model.tracking!
      end

      begin
        tracked do |list|
          block.call()
          return list
        end
      ensure
        models.each do |model|
          model.tracking! previously[model]
        end
      end
    end

    def self.tracked(&block)
      return @@tracked.last unless block
      @@tracked.push(list = [])
      begin
        block.call(*[list].slice(0, block.arity))
      ensure
        @@tracked.pop
      end
    end

    code_for 'app/document/transaction' do
      class << self
        public :transaction
      end

      def self.tracking(*args, &block)
        args.push(self) if args.empty?
        ::App::Document.tracking(*args, &block)
      end

      def self.tracked(*args, &block)
        ::App::Document.tracked(*args, &block)
      end

      def self.tracking=(boolean)
        @tracking = !!boolean
      end

      def self.tracking!(boolean = true)
        self.tracking = boolean
      end

      def self.tracking?
        @tracking = false unless defined?(@tracking)
        @tracking
      end

      def self.track!(doc)
        list = tracked
        list.push(doc) if list and tracking?
      end

      def track!(doc)
        self.class.track!(doc)
      end

      after_save{|doc| track!(doc)}
    end
  end
end


## FIXME - this shouldn't be defined here, but it depends on 'tracking'
#support above so here it stays - for now
#
#
  module Kernel
  private
    def transaction(&block)
      @transaction = nil unless defined?(@transaction)

      if @transaction
        return(block ? block.call(@transaction) : @transaction)
      end

      raise("** no transaction **") unless block

      stack = nil
      error = nil

      result =
        catch(:transaction) do
          App::Document.tracking do
            begin
              block.call(@transaction = App::Document.tracked)
            rescue Object
              error ||= $!
            ensure
              error ||= $!
              stack = @transaction
              @transaction = nil
            end
          end
        end

      result = [:rollback, error] if error # trigger rollback if an error was thrown....

      if result.is_a?(Array)
        case result.first
          when :rollback
            stack.flatten.uniq.reverse.compact.each do |object|
              next if object.respond_to?(:new_record?) && object.new_record?
              %w( rollback! rollback destroy! destroy delete! delete ).each do |strategy|
                break(object.send(strategy)) if object.respond_to?(strategy)
              end
            end
            result.last if result.size > 1
          when :commit
            result.last if result.size > 1
          else
            result
        end
      else
        result
      end

    ensure
      raise error if error
    end

    def transaction?
      defined?(@transaction) and @transaction
    end

    def rollback!(*value)
      raise($!) if $!
      throw(:transaction, [:rollback, value.first].compact)
    end

    def commit!(*value)
      throw(:transaction, [:commit, value.first].compact)
    end
  end
