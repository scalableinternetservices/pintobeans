require "test_helper"

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      username: "john_doe", 
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should register a new user" do
    post "/auth/register", params: {
      user: {
        username: "new_user",  # Also fixed to match assertion!
        password: "password123",
        password_confirmation: "password123"
      }
    }, as: :json
  
    assert_response :created
    json = JSON.parse(response.body)
  
    assert_equal "new_user", json["user"]["username"]
    assert_not_nil json["token"]
  end

  test "should not register duplicate username" do
    post "/auth/register", params: {
      user: {
        username: @user.username,
        password: "anotherpass",
        password_confirmation: "anotherpass"
      }
    }, as: :json

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    # Adjust this assertion based on your actual error response format
    assert json["errors"].present?
  end

  test "should login with valid credentials" do
    post "/auth/login", params: {
      user: {
        username: @user.username,
        password: "password123"
      }
    }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.username, json["user"]["username"]
    assert_not_nil json["token"]
  end

  test "should reject invalid login" do
    post "/auth/login", params: {
      user: {
        username: @user.username,
        password: "wrongpass"
      }
    }

    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "Invalid username or password", json["error"]
  end

  test "should return current user info from /auth/me" do
    token = JwtService.encode(@user)
    get "/auth/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @user.username, json["username"]
  end

  test "should reject /auth/me without token" do
    get "/auth/me"
    assert_response :unauthorized
  end
end