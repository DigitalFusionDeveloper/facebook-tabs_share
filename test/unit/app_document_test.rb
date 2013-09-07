require 'test_helper'

class AppDocumentTest < ActiveSupport::TestCase
##
#
  setup do
    @a = 
      assert do
        Class.new do
          def self.name() 'C' end
          include App::Document
        end
      end

    @b = 
      assert do
        Class.new do
          def self.name() 'B' end
          include App::Document
        end
      end
  end

##
#
  test "that we can track specific model creation in a block" do
    count = @a.count

    tracked =
      @a.tracking do
        3.times do
          @a.create
        end
      end

    assert{ tracked.all?{|doc| doc.is_a?(@a)} }
    assert{ tracked.count == 3 }
    assert{ @a.count == count + 3 }
  end

##
#
  test "that we can track **all** model creation in a block" do
    count = Map[:a, @a.count, :b, @b.count]

    tracked =
      App::Document.tracking do
        3.times do
          @a.create
          @b.create
        end
      end

    assert{ tracked.count == 6 }
    assert{ tracked.grep(@a).count == 3 }
    assert{ tracked.grep(@b).count == 3 }
    assert{ @a.count == count.a + 3 }
    assert{ @b.count == count.b + 3 }
  end

##
#
  test "because we can track docs we can have transactions - even on mongoid" do
    assert{ transaction{} }

    count = @a.count
    assert{ transaction{ 3.times{ @a.create } } }
    assert{ @a.count == count + 3 }

    count = @a.count
    assert{ transaction{ 3.times{ @a.create }; rollback! }; true }
    assert{ @a.count == count }

    count = @a.count
    assert{ transaction{ transaction{ 3.times{ @a.create } } } }
    assert{ @a.count == count + 3 }
  end
end
