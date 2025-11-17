require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  
  test "registers a valid user" do
    post "/auth/register", params: {
      user: {
        username: "KateLarrick",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "KateLarrick", body["user"]["username"]
    assert_not_nil body["token"]
  end

  test "fails registration with missing username" do
    post "/auth/register", params: {
      user: {
        password: "password123",
        password_confirmation: "password123"
      }
    }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "Username"
  end

  test "fails registration with short password" do
    post "/auth/register", params: {
      user: {
        username: "CheZimmerman",
        password: "123",
        password_confirmation: "123"
      }
    }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join, "Password"
  end

end
