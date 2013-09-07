require 'test_helper'

class ApiAuthTest < Test::Unit::TestCase
  include ApiTestHelper

  def setup
  end

  test "ping" do
    get "/api/ping"
    assert last_response.ok?
  end

  test "pong without auth" do
    get "/api/pong"

    assert status_for(last_response.status) =~ 400
  end

  test "pong with http basic auth" do
    password = "P@$$w0rd"

    make_user :password => password do |user|
      authorize user.email, password
      get "/api/pong"
      assert status_for(last_response.status) =~ 200
      assert parsed_response.get(:data, :current_user, :email) == user.email
    end
  end

  test "pong with http user token auth" do
    make_user do |user|
      token = Token.make!(user, :kind => 'api')

      begin
        header 'X-Api-Token', token.uuid
        get "/api/pong"
        assert status_for(last_response.status) =~ 200
        assert parsed_response.get(:data, :current_user, :email) == user.email
      ensure
        token.destroy
      end
    end
  end
end

