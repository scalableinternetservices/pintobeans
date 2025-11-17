require "test_helper"

class UpdatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @initiator = User.create!(
      username: "asker",
      password: "questions1234",
      password_confirmation: "questions1234"
      )
    
    @expert = User.create!(
      username: "expert", 
      password: "answers1234",
      password_confirmation: "answers1234"
      )
    
    ExpertProfile.create!(user: @expert)

    @conversation = Conversation.create!(
      title: "Test Conversation",
      status: "active",
      initiator: @initiator,
      assigned_expert: @expert
    )

    @message = Message.create!(
      conversation: @conversation,
      sender: @initiator,
      sender_role: "initiator",
      content: "Hello expert!",
      is_read: false
    )

    @initiator_token = JwtService.encode(@initiator)
    @expert_token = JwtService.encode(@expert)
  end

  test "should get updated conversations for user" do
    get "/api/conversations/updates",
        headers: { "Authorization" => "Bearer #{@initiator_token}" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal @conversation.title, json.first["title"]
  end

  test "should get recent messages for user" do
    get "/api/messages/updates",
        headers: { "Authorization" => "Bearer #{@expert_token}" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.length
    assert_equal "Hello expert!", json.first["content"]
  end

  test "should reject updates if no token provided" do
    get "/api/conversations/updates"
    assert_response :unauthorized
  end

  test "expert_queue should return waiting and assigned conversations" do
    Conversation.create!(
      title: "Waiting Conversation",
      status: "waiting",
      initiator: @initiator
    )

    get "/api/expert-queue/updates",
        headers: { "Authorization" => "Bearer #{@expert_token}" },
        as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_operator json["waitingConversations"].length, :>, 0
    assert_operator json["assignedConversations"].length, :>, 0
  end
end