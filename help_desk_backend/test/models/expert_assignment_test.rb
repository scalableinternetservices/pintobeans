require "test_helper"

class ExpertAssignmentTest < ActiveSupport::TestCase
  
  # TESTS FOR ASSIGNMENTS MISSING REQUIRED VALUES
  
  test "expert assignment that is missing conversation_id should not save" do
    
    # make valid user
    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )
    assert user.save, "valid user did not save"

    # make valid expert
    valid_expert = ExpertProfile.new(user_id: user.id, bio: "Valid user")
    assert valid_expert.save, "expert profile with valid user did not save"
    
    # make expert assignment
    expert_assignment2 = ExpertAssignment.new(
      expert_id: valid_expert.id,
      assigned_at: Time.current,
    )
    assert_not expert_assignment2.save, "invalid expert assignment (missing conversation_id) was saved"
  
  end

  test "expert assignment that is missing expert_id should not save" do

    # make valid user
    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )
    assert user.save, "valid user did not save"

    # make valid conversation
    conversation = Conversation.new(title: "Test Conversation", initiator_id: user.id)
    assert conversation.save, "conversation did not save"
    
    # make expert assignment
    expert_assignment2 = ExpertAssignment.new(
      conversation_id: conversation.id,
      #expert_id: valid_expert.id,
      assigned_at: Time.current,
    )
    assert_not expert_assignment2.save, "invalid expert assignment (missing expert_id) was saved"

  end

  test "expert assignment that is missing assigned_at should not save" do

    # make valid user
    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )
    assert user.save, "valid user did not save"

    # make valid expert
    valid_expert = ExpertProfile.new(user_id: user.id, bio: "Valid user")
    assert valid_expert.save, "expert profile with valid user did not save"

    # make valid conversation
    conversation = Conversation.new(title: "Test Conversation", initiator_id: user.id)
    assert conversation.save, "conversation did not save"
    
    # make expert assignment
    expert_assignment3 = ExpertAssignment.new(
      conversation_id: conversation.id,
      expert_id: valid_expert.id,
      #assigned_at: Time.current,
    )
    assert_not expert_assignment3.save, "invalid expert assignment (missing assigned_at) was saved"

  end


  # TESTS FOR DEFAULT STATUS

  test "expert assignment that is missing status should still have status = Active" do
    
    # make valid user
    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )
    assert user.save, "valid user did not save"

    # make valid expert
    valid_expert = ExpertProfile.new(user_id: user.id, bio: "Valid user")
    assert valid_expert.save, "expert profile with valid user did not save"

    # make valid conversation
    conversation = Conversation.new(title: "Test Conversation", initiator_id: user.id)
    assert conversation.save, "conversation did not save"
    
    # make expert assignment
    expert_assignment4 = ExpertAssignment.new(
      conversation_id: conversation.id,
      expert_id: valid_expert.id,
      assigned_at: Time.current,
    )
    assert expert_assignment4.save, "valid expert assignment was not saved"
    
    expected_string = "Active"
    assert_equal expected_string, expert_assignment4.status, "status is not what was expected"
  end

  test "expert assignment that overwrites default status as Inactive should save" do

    # make valid user
    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )
    assert user.save, "valid user did not save"

    # make valid expert
    valid_expert = ExpertProfile.new(user_id: user.id, bio: "Valid user")
    assert valid_expert.save, "expert profile with valid user did not save"

    # make valid conversation
    conversation = Conversation.new(title: "Test Conversation", initiator_id: user.id)
    assert conversation.save, "conversation did not save"
    
    # make expert assignment
    expert_assignment5 = ExpertAssignment.new(
      conversation_id: conversation.id,
      expert_id: valid_expert.id,
      assigned_at: Time.current,
      status: "Inactive"
    )
    assert expert_assignment5.save, "valid expert assignment was not saved"

    expected_string = "Inactive"
    assert_equal expected_string, expert_assignment5.status, "status is not what was expected"
  end

end
