##
#
  require 'minitest/unit'
  require 'minitest/spec'
  require 'minitest/autorun'

##
#
  MiniTest::Unit::TestCase.i_suck_and_my_tests_are_order_dependent!

## hax in a sane lifecycle DSL
#
  class MiniTest::Unit::TestCase
    BeforeAll = Hash.new
    AfterAll = Hash.new

    Before = Hash.new
    After = Hash.new

    class << self
      def before_all(&block)
        blocks = (BeforeAll[self] ||= [])

        blocks.push(block) if block

        ancestors.reverse.each do |ancestor|
          blocks = Array(BeforeAll[ancestor])
          blocks.each{|block| instance_eval(&block)}
        end

        self
      end

      def after_all(&block)
        blocks = (AfterAll[self] ||= [])

        blocks.push(block) if block

        ancestors.reverse.each do |ancestor|
          blocks = Array(BeforeAll[ancestor])
          blocks.each{|block| instance_eval(&block)}
        end

        self
      end

      def before(&block)
        blocks = (Before[self] ||= [])
        blocks.push(block) if block

        ancestors.reverse.map do |ancestor|
          blocks = Array(Before[ancestor])
        end.flatten.compact
      end
      alias_method(:setup, :before)

      def after(&block)
        blocks = (After[self] ||= [])
        blocks.push(block) if block

        ancestors.reverse.map do |ancestor|
          blocks = Array(After[ancestor])
        end.flatten.compact
      end
      alias_method(:teardown, :after)
    end

    def setup
      blocks = self.class.before
      blocks.each{|block| instance_eval(&block)}
    end

    def teardown
      blocks = self.class.after
      blocks.each{|block| instance_eval(&block)}
    end

  end

## due to lack of transactions in mongoid we snapshot the db before any test
# is run and then restore to this snapshot before each test *suite* is run.  we
# would like to restore before each test but it is simple too slow.  the side
# effect is that tests can pollute one another, but test suites cannot.  live
# with it.
#
  #App.db_snapshot()
  #at_exit{ App.db_restore() }
  test_db_yml = File.join(Rails.root, 'test/db.yml')
  abort('rake db:test:prepare ### did you forget?') unless test(?e, test_db_yml)
  TestDb = YAML.load(IO.read(test_db_yml))


  class MiniTest::Unit::TestCase
    before_all do
      App.db_restore(TestDb)
    end
  end

## tweak the minitest runner to:
#
#   1) snapshot the test db before *any* tests/suites are run
#
#   2) restore to this condition before each suite.  this is essentially a
#   workaround for the lack of transactions in mongo and the impact of this on
#   testing...
#

  class MiniTest::Unit
    alias_method('___run_suite__', '_run_suite')

    def _run_suite(suite, type)
      list_of_test_methods = Array(suite.send("#{ type }_methods"))
      going_to_run_tests = !list_of_test_methods.empty?

      if going_to_run_tests
        suite.before_all()
      end

      ___run_suite__(suite, type)
    end
  end
  MiniTest::Unit.runner = MiniTest::Unit.new

##
#
  class MiniTest::Unit::TestCase
    @@test_method_filter ||= /./

    class << self
      alias_method('__test_methods__', 'test_methods')

      def test_methods
        __test_methods__.grep(@@test_method_filter)
      end

      def test_method_filter
        @@test_method_filter
      end

      def test_method_filter=(test_method_filter)
        @@test_method_filter =
          if test_method_filter =~ %r|\A\s*/|
            eval(test_method_filter)
          else
            /^\s*#{ Regexp.escape(test_method_filter) }/i
          end
      end
    end
  end

  require "rails/test_help"

###  require "context"
 
  context = Module.new do
    def contexts
      @contexts ||= []
    end

    def context(*args, &block)
      return contexts.last if(args.empty? and block.nil?)
      context = Slug.for(*args, :join => '_')
      contexts.push(context)
      begin
        block.call(context)
      ensure
        contexts.pop
      end
    end

    def testing(*args, &block)
      test_name = Slug.for(*args, :join => '_')
      method_name = ['test', contexts, test_name].flatten.join(context ? '__' : '_')
      define_method(method_name, &block)
    end

    def test(*args, &block)
      testing(*args, &block)
    end
  end

  [
    ActiveSupport::TestCase,
    MiniTest::Unit::TestCase,
    ActionController::IntegrationTest
  ].each do |klass|
    klass.send(:extend, context)
  end


## *** MEGA HACK ***
#
# we prefer to use Spec as our base class for rails so we lie to rails about
# what MiniTest::Unit::TestCase really is....
#
#
=begin
  test_case = MiniTest::Unit::TestCase

  begin
    MiniTest::Unit.send(:remove_const, :TestCase)
    MiniTest::Unit.send(:const_set, :TestCase, MiniTest::Spec)
    require "rails/test_help"
  ensure
    MiniTest::Unit.send(:remove_const, :TestCase)
    MiniTest::Unit.send(:const_set, :TestCase, test_case)
  end

  class MiniTest::Spec
    class << self
      alias_method 'test', 'it'
      alias_method 'context', 'describe'
    end
  end
=end
