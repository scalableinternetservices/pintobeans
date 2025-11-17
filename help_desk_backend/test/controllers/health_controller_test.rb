require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest

  test "GET /health returns ok status and timestamp" do

    get "/health"
    
    assert_response :success
    json = JSON.parse(response.body)

    assert_equal "ok", json["status"]
    assert_not_nil json["timestamp"]
    
  end

end
