require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
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

    @conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting"
    )

    # Mock LLM calls - return NO_ANSWER for auto-response by default
    BedrockClient.any_instance.stubs(:call).returns({
      output_text: "NO_ANSWER",
      raw_response: nil
    })
  end

  # GET /conversations/:conversation_id/messages tests
  test "GET /conversations/:conversation_id/messages returns messages for conversation" do
    message1 = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "First message",
      is_read: false
    )

    message2 = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Second message",
      is_read: true
    )

    get "/conversations/#{@conversation.id}/messages", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.length
    assert_equal message1.id.to_s, body.first["id"]
    assert_equal message2.id.to_s, body.second["id"]
  end

  test "GET /conversations/:conversation_id/messages returns messages ordered by created_at asc" do
    message2 = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Second message",
      is_read: false,
      created_at: 1.hour.ago
    )

    message1 = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "First message",
      is_read: false,
      created_at: 2.hours.ago
    )

    get "/conversations/#{@conversation.id}/messages", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.length
    assert_equal message1.id.to_s, body.first["id"]
    assert_equal message2.id.to_s, body.second["id"]
  end

  test "GET /conversations/:conversation_id/messages returns empty array when no messages" do
    get "/conversations/#{@conversation.id}/messages", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body
  end

  test "GET /conversations/:conversation_id/messages returns 404 if conversation not found" do
    get "/conversations/99999/messages", headers: @headers

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "GET /conversations/:conversation_id/messages returns 404 if user is not initiator or assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    other_conversation = Conversation.create!(
      title: "Other Conversation",
      initiator: other_user,
      status: "waiting"
    )

    get "/conversations/#{other_conversation.id}/messages", headers: @headers

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "GET /conversations/:conversation_id/messages allows access if user is assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    expert_conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: other_user,
      assigned_expert: @user,
      status: "active"
    )

    message = Message.create!(
      conversation: expert_conversation,
      sender: other_user,
      sender_role: "initiator",
      content: "Expert message",
      is_read: false
    )

    get "/conversations/#{expert_conversation.id}/messages", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal message.id.to_s, body.first["id"]
  end

  test "GET /conversations/:conversation_id/messages requires authentication" do
    get "/conversations/#{@conversation.id}/messages"

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  test "GET /conversations/:conversation_id/messages includes all required fields" do
    message = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )

    get "/conversations/#{@conversation.id}/messages", headers: @headers

    assert_response :success
    body = JSON.parse(response.body)
    message_data = body.first

    assert_not_nil message_data["id"]
    assert_not_nil message_data["conversationId"]
    assert_not_nil message_data["senderId"]
    assert_not_nil message_data["senderUsername"]
    assert_not_nil message_data["senderRole"]
    assert_not_nil message_data["content"]
    assert_not_nil message_data["timestamp"]
    assert_not_nil message_data["isRead"]
  end

  # POST /messages tests
  test "POST /messages creates a new message" do
    post "/messages",
         params: { conversation_id: @conversation.id, content: "New message" },
         headers: @headers,
         as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "New message", body["content"]
    assert_equal @user.id.to_s, body["senderId"]
    assert_equal @user.username, body["senderUsername"]
    assert_equal "initiator", body["senderRole"]
    assert_equal false, body["isRead"]
  end

  test "POST /messages sets sender to current user" do
    post "/messages",
         params: { conversation_id: @conversation.id, content: "New message" },
         headers: @headers,
         as: :json

    assert_response :created
    message = Message.last
    assert_equal @user.id, message.sender_id
  end

  test "POST /messages sets sender_role to initiator when user is initiator" do
    post "/messages",
         params: { conversation_id: @conversation.id, content: "New message" },
         headers: @headers,
         as: :json

    assert_response :created
    message = Message.last
    assert_equal "initiator", message.sender_role
  end

  test "POST /messages sets sender_role to expert when user is assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    expert_conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: other_user,
      assigned_expert: @user,
      status: "active"
    )

    post "/messages",
         params: { conversation_id: expert_conversation.id, content: "Expert message" },
         headers: @headers,
         as: :json

    assert_response :created
    message = Message.last
    assert_equal "expert", message.sender_role
  end

  test "POST /messages sets is_read to false by default" do
    post "/messages",
         params: { conversation_id: @conversation.id, content: "New message" },
         headers: @headers,
         as: :json

    assert_response :created
    message = Message.last
    assert_equal false, message.is_read
  end

  test "POST /messages updates conversation status to active if waiting and expert assigned" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    waiting_conversation = Conversation.create!(
      title: "Waiting Conversation",
      initiator: @user,
      assigned_expert: other_user,
      status: "waiting"
    )

    post "/messages",
         params: { conversation_id: waiting_conversation.id, content: "New message" },
         headers: @headers,
         as: :json

    assert_response :created
    waiting_conversation.reload
    assert_equal "active", waiting_conversation.status
  end

  test "POST /messages requires content" do
    post "/messages",
         params: { conversation_id: @conversation.id },
         headers: @headers,
         as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"], "Content can't be blank"
  end

  test "POST /messages rejects empty content" do
    post "/messages",
         params: { conversation_id: @conversation.id, content: "" },
         headers: @headers,
         as: :json

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"], "Content can't be blank"
  end

  test "POST /messages requires conversation_id" do
    post "/messages",
         params: { content: "Test message" },
         headers: @headers,
         as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "POST /messages returns 404 if conversation not found" do
    post "/messages",
         params: { conversation_id: 99999, content: "Test message" },
         headers: @headers,
         as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "POST /messages returns 404 if user is not initiator or assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    other_conversation = Conversation.create!(
      title: "Other Conversation",
      initiator: other_user,
      status: "waiting"
    )

    post "/messages",
         params: { conversation_id: other_conversation.id, content: "Test message" },
         headers: @headers,
         as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "POST /messages requires authentication" do
    post "/messages", params: { conversation_id: @conversation.id, content: "Test" }

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  test "POST /messages response includes all required fields" do
    post "/messages",
         params: { conversation_id: @conversation.id, content: "New message" },
         headers: @headers,
         as: :json

    assert_response :created
    body = JSON.parse(response.body)

    assert_not_nil body["id"]
    assert_equal @conversation.id.to_s, body["conversationId"]
    assert_equal @user.id.to_s, body["senderId"]
    assert_equal @user.username, body["senderUsername"]
    assert_equal "initiator", body["senderRole"]
    assert_equal "New message", body["content"]
    assert_not_nil body["timestamp"]
    assert_equal false, body["isRead"]
  end

  # PUT /messages/:id/read tests
  test "PUT /messages/:id/read marks message as read" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    message = Message.create!(
      conversation: @conversation,
      sender: other_user,
      sender_role: "initiator",
      content: "Unread message",
      is_read: false
    )

    put "/messages/#{message.id}/read", headers: @headers, as: :json

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal true, body["success"]

    message.reload
    assert_equal true, message.is_read
  end

  test "PUT /messages/:id/read returns 404 if message not found" do
    put "/messages/99999/read", headers: @headers, as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Message not found", body["error"]
  end

  test "PUT /messages/:id/read returns 404 if user is not initiator or assigned expert" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    other_conversation = Conversation.create!(
      title: "Other Conversation",
      initiator: other_user,
      status: "waiting"
    )

    message = Message.create!(
      conversation: other_conversation,
      sender: other_user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )

    put "/messages/#{message.id}/read", headers: @headers, as: :json

    assert_response :not_found
    body = JSON.parse(response.body)
    assert_equal "Conversation not found", body["error"]
  end

  test "PUT /messages/:id/read returns 403 if user tries to mark own message as read" do
    message = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "My message",
      is_read: false
    )

    put "/messages/#{message.id}/read", headers: @headers, as: :json

    assert_response :forbidden
    body = JSON.parse(response.body)
    assert_equal "Cannot mark your own messages as read", body["error"]

    message.reload
    assert_equal false, message.is_read
  end

  test "PUT /messages/:id/read allows expert to mark initiator message as read" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    expert_conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: other_user,
      assigned_expert: @user,
      status: "active"
    )

    message = Message.create!(
      conversation: expert_conversation,
      sender: other_user,
      sender_role: "initiator",
      content: "Initiator message",
      is_read: false
    )

    put "/messages/#{message.id}/read", headers: @headers, as: :json

    assert_response :success
    message.reload
    assert_equal true, message.is_read
  end

  test "PUT /messages/:id/read allows initiator to mark expert message as read" do
    other_user = User.create!(
      username: "expertuser",
      password: "password123",
      password_confirmation: "password123"
    )

    expert_conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: @user,
      assigned_expert: other_user,
      status: "active"
    )

    message = Message.create!(
      conversation: expert_conversation,
      sender: other_user,
      sender_role: "expert",
      content: "Expert message",
      is_read: false
    )

    put "/messages/#{message.id}/read", headers: @headers, as: :json

    assert_response :success
    message.reload
    assert_equal true, message.is_read
  end

  test "PUT /messages/:id/read requires authentication" do
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )

    message = Message.create!(
      conversation: @conversation,
      sender: other_user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )

    put "/messages/#{message.id}/read"

    assert_response :unauthorized
    body = JSON.parse(response.body)
    assert_equal "Unauthorized", body["error"]
  end

  test "POST /messages triggers auto-response when expert has FAQ" do
    expert_user = User.create!(
      username: "expert",
      password: "password123",
      password_confirmation: "password123"
    )
    expert_profile = ExpertProfile.create!(
      user: expert_user,
      bio: "I help with account issues",
      faq: [
        { question: "How do I reset my password?", answer: "Click 'Forgot Password' on the login page." }
      ]
    )

    conversation_with_expert = Conversation.create!(
      title: "Password Help",
      initiator: @user,
      assigned_expert: expert_user,
      status: "active"
    )

    # Mock LLM to return a helpful response
    BedrockClient.any_instance.stubs(:call).returns({
      output_text: "Click 'Forgot Password' on the login page.",
      raw_response: nil
    })

    initial_message_count = conversation_with_expert.messages.count

    post "/messages",
         params: { conversation_id: conversation_with_expert.id, content: "How do I reset my password?" },
         headers: @headers,
         as: :json

    assert_response :created

    # Should create both the user's message and the auto-response
    assert_equal initial_message_count + 2, conversation_with_expert.messages.count

    # Check that auto-response was created
    auto_response = conversation_with_expert.messages.order(created_at: :desc).first
    assert_equal expert_user.id, auto_response.sender_id
    assert_equal "expert", auto_response.sender_role
  end
end

