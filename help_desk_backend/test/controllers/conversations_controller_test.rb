require "test_helper"

class ConversationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )
    @token = JwtService.encode(@user)
    @headers = {
      "Authorization" => "Bearer #{@token}",
      "Content-Type" => "application/json"
    }
  end

  # GET /conversations tests
  test "GET /conversations returns user's conversations" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting"
    )
    
    get "/conversations", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal conversation.id.to_s, body.first["id"]
    assert_equal "Test Conversation", body.first["title"]
  end

  test "GET /conversations returns empty array when user has no conversations" do
    get "/conversations", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body
  end

  test "GET /conversations only returns conversations where user is initiator or assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Conversation where user is initiator
    my_conversation = Conversation.create!(
      title: "My Conversation",
      initiator: @user,
      status: "waiting"
    )
    
    # Conversation where user is assigned expert
    expert_conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: other_user,
      assigned_expert: @user,
      status: "active"
    )
    
    # Conversation where user is not involved
    other_conversation = Conversation.create!(
      title: "Other Conversation",
      initiator: other_user,
      status: "waiting"
    )
    
    get "/conversations", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.length
    
    conversation_ids = body.map { |c| c["id"] }
    assert_includes conversation_ids, my_conversation.id.to_s
    assert_includes conversation_ids, expert_conversation.id.to_s
    assert_not_includes conversation_ids, other_conversation.id.to_s
  end

  test "GET /conversations returns conversations ordered by updated_at desc" do
    conversation1 = Conversation.create!(
      title: "First Conversation",
      initiator: @user,
      status: "waiting",
      updated_at: 2.hours.ago
    )
    
    conversation2 = Conversation.create!(
      title: "Second Conversation",
      initiator: @user,
      status: "waiting",
      updated_at: 1.hour.ago
    )
    
    get "/conversations", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.length
    assert_equal conversation2.id.to_s, body.first["id"]
    assert_equal conversation1.id.to_s, body.second["id"]
  end

  test "GET /conversations requires authentication" do
    get "/conversations"
    
    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  test "GET /conversations includes all required fields" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting",
      last_message_at: Time.current
    )
    
    get "/conversations", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    conversation_data = body.first
    
    assert_not_nil conversation_data["id"]
    assert_not_nil conversation_data["title"]
    assert_not_nil conversation_data["status"]
    assert_not_nil conversation_data["questionerId"]
    assert_not_nil conversation_data["questionerUsername"]
    assert_not_nil conversation_data["createdAt"]
    assert_not_nil conversation_data["updatedAt"]
    assert_not_nil conversation_data["lastMessageAt"]
    assert_not_nil conversation_data["unreadCount"]
  end

  # GET /conversations/:id tests
  test "GET /conversations/:id returns specific conversation" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting"
    )
    
    get "/conversations/#{conversation.id}", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal conversation.id.to_s, body["id"]
    assert_equal "Test Conversation", body["title"]
    assert_equal @user.id.to_s, body["questionerId"]
    assert_equal @user.username, body["questionerUsername"]
  end

  test "GET /conversations/:id returns 404 if conversation not found" do
    get "/conversations/99999", headers: @headers
    
    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "GET /conversations/:id returns 404 if user is not initiator or assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )
    
    conversation = Conversation.create!(
      title: "Other Conversation",
      initiator: other_user,
      status: "waiting"
    )
    
    get "/conversations/#{conversation.id}", headers: @headers
    
    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "GET /conversations/:id allows access if user is assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )
    
    conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: other_user,
      assigned_expert: @user,
      status: "active"
    )
    
    get "/conversations/#{conversation.id}", headers: @headers
    
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal conversation.id.to_s, body["id"]
    assert_equal @user.id.to_s, body["assignedExpertId"]
  end

  test "GET /conversations/:id requires authentication" do
    conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting"
    )
    
    get "/conversations/#{conversation.id}"
    
    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  # POST /conversations tests
  test "POST /conversations creates a new conversation" do
    post "/conversations",
         params: { title: "New Conversation" },
         headers: @headers,
         as: :json
    
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New Conversation", body["title"]
    assert_equal "waiting", body["status"]
    assert_equal @user.id.to_s, body["questionerId"]
    assert_equal @user.username, body["questionerUsername"]
    assert_nil body["assignedExpertId"]
  end

  test "POST /conversations sets initiator to current user" do
    post "/conversations",
         params: { title: "New Conversation" },
         headers: @headers,
         as: :json
    
    assert_response :created
    conversation = Conversation.last
    assert_equal @user.id, conversation.initiator_id
  end

  test "POST /conversations sets status to waiting" do
    post "/conversations",
         params: { title: "New Conversation" },
         headers: @headers,
         as: :json
    
    assert_response :created
    conversation = Conversation.last
    assert_equal "waiting", conversation.status
  end

  test "POST /conversations sets last_message_at" do
    post "/conversations",
         params: { title: "New Conversation" },
         headers: @headers,
         as: :json
    
    assert_response :created
    conversation = Conversation.last
    assert_not_nil conversation.last_message_at
  end

  test "POST /conversations requires title" do
    post "/conversations",
         params: {},
         headers: @headers,
         as: :json
    
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"], "Title can't be blank"
  end

  test "POST /conversations rejects empty title" do
    post "/conversations",
         params: { title: "" },
         headers: @headers,
         as: :json
    
    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"], "Title can't be blank"
  end

  test "POST /conversations requires authentication" do
    post "/conversations", params: { title: "Test" }
    
    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  test "POST /conversations ignores id parameter" do
    post "/conversations",
         params: { title: "New Conversation", id: 999 },
         headers: @headers,
         as: :json
    
    assert_response :created
    conversation = Conversation.last
    assert_not_equal 999, conversation.id
    assert_equal "New Conversation", conversation.title
  end

  test "POST /conversations response includes all required fields" do
    post "/conversations",
         params: { title: "New Conversation" },
         headers: @headers,
         as: :json
    
    assert_response :created
    body = JSON.parse(response.body)
    
    assert_not_nil body["id"]
    assert_equal "New Conversation", body["title"]
    assert_equal "waiting", body["status"]
    assert_equal @user.id.to_s, body["questionerId"]
    assert_equal @user.username, body["questionerUsername"]
    assert_nil body["assignedExpertId"]
    assert_nil body["assignedExpertUsername"]
    assert_not_nil body["createdAt"]
    assert_not_nil body["updatedAt"]
    assert_not_nil body["lastMessageAt"]
    assert_not_nil body["unreadCount"]
  end
end

