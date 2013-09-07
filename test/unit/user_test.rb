require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "that the system has a root user" do
    assert{ User.root }
  end

  test "that a user can be created with an email and password" do
    assert{
      make_user.destroy
      true
    }
  end

  test "that users can be authenticated by email and password" do
    assert{
      make_user :password => :password do |user|
        assert{ User.authenticate(user.email, :password) == user }
      end
      true
    }
  end

  test "roles can be added and removed" do
    #assert{
      make_user do |user|
        user.add_role!('a')
        assert{ user.roles.include?('a') }

        user.add_role('b')
        assert{ user.roles.include?('b') }
        assert{ !user.reload.roles.include?('b') }

        user.add_role('c')
        assert{ user.roles.include?('c') }
        user.save
        assert{ user.reload.roles.include?('c') }

        user.remove_role!('c')
        assert{ !user.reload.roles.include?('c') }

        user.remove_roles!('a', 'b')
        assert{ !user.reload.roles.include?('a') }
        assert{ !user.reload.roles.include?('b') }
      end
      true
    #}
  end
end
