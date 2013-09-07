##
#
  ENV["RAILS_ENV"] = "test"

  require File.expand_path('../../config/environment', __FILE__)

  require "#{ Rails.root }/test/kill_fixtures.rb"
  require "#{ Rails.root }/test/test_classes.rb"

##
#
  first, last = ARGV.join(' ').split(Regexp.union('-n', '--name'), 2)
  if last
    test_method_filter = last.strip.split(/\s+/, 2).first
    MiniTest::Unit::TestCase.test_method_filter = test_method_filter unless test_method_filter.blank?
  end

##
#
  TestHelper = proc do
    alias_method('__assert__', 'assert')

    def assert(*args, &block)
      deferred = lambda do
        if block
          label = "assert(#{ args.join(' ') })"
          result = nil
          assert_nothing_raised{ result = block.call }
          __assert__(result, label)
          result
        else
          result = args.shift
          label = "assert(#{ args.join(' ') })"
          __assert__(result, label)
          result
        end
      end
      @asserting ? @assertion_stack.push(deferred) : deferred.call()
    end

    def assert_status_match(expected, *args)
      options = args.extract_options!.to_options!

      expected = Dao::Status.for(expected)
      actual = Dao::Status.for(options[:actual] || options[:with] || args.shift)

      expected =~ actual
    end

    def subclass_of exception
      class << exception
        def ==(other) super or self > other end
      end
      exception
    end

    def status_for(status)
      Dao::Status.new(status)
    end

    def asserting(&block)
      @asserting = true
      block.call(@assertion_stack||=[])
      errors = []

      @assertion_stack.each do |deferred|
        begin
          deferred.call()
        rescue Object => e
          errors.push(e)
        end
      end

      unless errors.empty?
        error = errors.shift
        class << error
          attr_accessor :errors
        end
        error.errors = errors
        error.message.replace("#{ error.message } (and #{ errors.size } more...)") unless errors.empty?
        raise error
      end

    ensure
      @assertion_stack.clear
      @asserting = false 
    end

    def tmpdir(*args, &block)
      Dir.tmpdir(*args, &block)
    end

  ## handles on seed data objects and factories used in testing 
  #
    def root 
      @root ||= User.root
    end

    def jane 
      @jane ||= User.jane
    end

    def user
      @user ||= jane
    end

    def john
      @john ||= User.john
    end

    def api(*args)
      Api.new(*args)
    end

    def make_user(*args, &block)
      options = args.extract_options!.to_options!

      email = args.shift || options[:email] || Fake.email
      password = args.shift || options[:password] || Fake.password

      options[:email] = email
      options[:password] = password

      user = assert{ User.make!(options) }

      if block
        begin
          block.call(user)
        ensure
          assert{ user.destroy rescue nil; true }
        end
      else
        user
      end
    end

    def making(*args, &block)
      options = args.extract_options!.to_options!
      things = (args + options.keys).map{|arg| arg.to_s}

      objects = []

      things.each do |thing|
        method = "make_#{ thing }"
        key = thing.to_sym

        if options.has_key?(key)
          args = options[key]
          args = args.is_a?(Array) ? args : [args]
        else
          args = []
        end
        
        objects.push(send(method, *args))
      end

      if block
        begin
          block.call(*objects)
        ensure
          objects.map{|object| assert{ object.destroy rescue nil; true}}
        end
      else
        objects
      end
    end
  end

  class ::ActiveSupport::TestCase
    class_eval(&TestHelper)
  end

  class ::Test::Unit::TestCase
    class_eval(&TestHelper)
  end

module ApiTestHelper
  require 'rack/test'
  include Rack::Test::Methods

  def app
    Dojo4::Application
  end

  def parsed_response
    Map.from_hash(JSON.parse(last_response.body))
  end

  def data
    parsed_response[:data]
  end

  def errors
    parsed_response[:errors]
  end

  def status
    parsed_response[:status]
  end

  def status_for(status)
    Dao::Status.new(status)
  end

  def full_path(url)
    DefaultUrlOptions[:protocol] + DefaultUrlOptions[:host] + (DefaultUrlOptions[:port] ? ":#{DefaultUrlOptions[:port]}" : ":80") + url
  end
end
