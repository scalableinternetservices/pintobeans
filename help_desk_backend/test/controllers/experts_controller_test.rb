require "test_helper"

class ExpertsControllerTest < ActionDispatch::IntegrationTest

  setup do

    @user = User.create!(
      username: "expert_user",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    @expert_profile = ExpertProfile.create!(user_id: @user.id, bio: "Expert Bio")

    @token = JwtService.encode(@user)

    @headers = {
      "Authorization" => "Bearer #{@token}",
      "Content-Type" => "application/json"
    }
  end

  # GET /expert/profile: get the current expert's profile.
  test "GET /expert/profile returns expert profile" do
    get "/expert/profile", headers: @headers
    assert_response :success

    json = JSON.parse(@response.body)
    assert_equal @expert_profile.id, json["id"]
  end

  # POST /expert/conversations/:conversation_id/claim: claim a conversation as an expert
  test "POST /expert/conversations/:conversation_id/claim assigns conversation to expert" do

    conversation = Conversation.create!(
      title: "Unclaimed Convo!",
      initiator: @user,
      status: "waiting"
    )

    post "/expert/conversations/#{conversation.id}/claim",
      headers: @headers

    assert_response :success

    json = JSON.parse(@response.body)
    assert json["success"]

    # reload conversation and verify expert assignment
    conversation.reload
    assert_equal @expert_profile.user_id, conversation.assigned_expert.id
    assert_equal "active", conversation.status

    # make sure ExpertAssignment is created
    assignment = ExpertAssignment.find_by(conversation: conversation, expert_id: @expert_profile.id)
    assert_not_nil assignment
    assert_equal "active", assignment.status
  end

  
  # POST /expert/conversations/:conversation_id/unclaim: unclaim a conversation (return it to the waiting queue).
  test "POST /expert/conversations/:conversation_id/unclaim unassigns the conversation" do

    conversation = Conversation.create!(
      title: "Assigned Conversation",
      initiator: @user,
      status: "active",
      assigned_expert: @expert_profile.user
    )

    assignment = ExpertAssignment.create!(
      conversation: conversation,
      expert_id: @expert_profile.id,
      status: "active",
      assigned_at: Time.current
    )

    post "/expert/conversations/#{conversation.id}/unclaim",
      headers: @headers

    assert_response :success
    json = JSON.parse(@response.body)
    assert json["success"]

    conversation.reload
    assert_nil conversation.assigned_expert
    assert_equal "waiting", conversation.status

    assignment.reload
    assert_equal "resolved", assignment.status
    assert_not_nil assignment.resolved_at
  end


  # PUT /expert/profile: update the expert's profile.
  test "PUT /expert/profile updates the expert profile" do

    update_params = {
      expert_profile: {
        bio: "Updated Bio",
        knowledge_base_links: ["https://example.com/article1"]
      }
    }

    put "/expert/profile",
      params: update_params.to_json,
      headers: @headers

    assert_response :success

    json = JSON.parse(@response.body)

    # Verify returned fields updated correctly
    assert_equal "Updated Bio", json["bio"]
    assert_equal ["https://example.com/article1"], json["knowledge_base_links"]

    # Reload and verify DB update
    @expert_profile.reload
    assert_equal "Updated Bio", @expert_profile.bio
    assert_equal ["https://example.com/article1"], @expert_profile.knowledge_base_links
  end


  # GET /expert/assignments/history: get the expert's assignment history.
  test "GET /expert/assignments/history returns expert assignments" do
    
    # Create some conversations
    convo1 = Conversation.create!(
      title: "First Assignment",
      initiator: @user,
      status: "active",
      assigned_expert: @expert_profile.user
    )
    convo2 = Conversation.create!(
      title: "Second Assignment",
      initiator: @user,
      status: "active",
      assigned_expert: @expert_profile.user
    )

    # Create corresponding ExpertAssignments
    assignment1 = ExpertAssignment.create!(
      conversation: convo1,
      expert_id: @expert_profile.id,
      status: "active",
      assigned_at: 2.days.ago
    )
    assignment2 = ExpertAssignment.create!(
      conversation: convo2,
      expert_id: @expert_profile.id,
      status: "resolved",
      assigned_at: 1.day.ago,
      resolved_at: Time.current
    )

    get "/expert/assignments/history", headers: @headers
    assert_response :success

    json = JSON.parse(@response.body)

    # Verify we got an array with 2 assignments
    assert_equal 2, json.size

    # Check first assignment (most recent first)
    assert_equal assignment2.id, json[0]["id"].to_i
    assert_equal assignment2.conversation_id, json[0]["conversationId"].to_i
    assert_equal assignment2.expert_id, json[0]["expertId"].to_i
    assert_equal "resolved", json[0]["status"]
    assert_not_nil json[0]["assignedAt"]
    assert_not_nil json[0]["resolvedAt"]

    # Check second assignment
    assert_equal assignment1.id, json[1]["id"].to_i
    assert_equal "active", json[1]["status"]
    assert_nil json[1]["resolvedAt"]
  end


  # GET /expert/queue: get the expert queue (waiting and assigned conversations)
  test "GET /expert/queue returns waiting and assigned conversations" do

    waiting_conversation = Conversation.create!(
      title: "Waiting Question",
      initiator: @user,
      status: "waiting",
    )
  
    assigned_conversation = Conversation.create!(
      title: "Assigned Question Test",
      initiator: @user,
      status: "active",
      assigned_expert: @expert_profile.user
    )
  
    get "/expert/queue", headers: @headers
    assert_response :success
  
    json = JSON.parse(@response.body)
  
    assert json.key?("waitingConversations")
    assert json.key?("assignedConversations")
  
    waiting_ids = json["waitingConversations"].map { |c| c["id"].to_i }
    assert_includes waiting_ids, waiting_conversation.id
  
    assigned_ids = json["assignedConversations"].map { |c| c["id"].to_i }
    assert_includes assigned_ids, assigned_conversation.id
  end
end
