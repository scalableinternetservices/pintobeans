require "test_helper"

class MessageTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      username: "testuser",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Create a minimal Conversation for testing
    # Note: This assumes a Conversation model exists. If not, create it first.
    @conversation = Conversation.create!(
      title: "Test Conversation",
      initiator: @user,
      status: "waiting",
    )
  end

  test "should not save message without conversation" do
    message = Message.new(
      sender: @user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )
    assert_not message.save, "invalid message (no conversation) was saved"
  end

  test "should not save message without sender" do
    message = Message.new(
      conversation: @conversation,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )
    assert_not message.save, "invalid message (no sender) was saved"
  end

  test "should not save message without sender_role" do
    # Create a user who is NOT the initiator or expert of the conversation
    other_user = User.create!(
      username: "otheruser",
      password: "password123",
      password_confirmation: "password123"
    )
    
    message = Message.new(
      conversation: @conversation,
      sender: other_user,
      content: "Test message",
      is_read: false
    )
    assert_not message.save, "invalid message (no sender_role) was saved"
  end

  test "should not save message with invalid sender_role" do
    message = Message.new(
      conversation: @conversation,
      sender: @user,
      sender_role: "invalid_role",
      content: "Test message",
      is_read: false
    )
    assert_not message.save, "invalid message (invalid sender_role) was saved"
  end

  test "should not save message without content" do
    message = Message.new(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      is_read: false
    )
    assert_not message.save, "invalid message (no content) was saved"
  end

  test "should save valid message with initiator role" do
    message = Message.new(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )
    assert message.save, "valid message did not save"
  end

  test "should save valid message with expert role" do
    expert_user = User.create!(
      username: "expertuser",
      password: "password123",
      password_confirmation: "password123"
    )
    
    message = Message.new(
      conversation: @conversation,
      sender: expert_user,
      sender_role: "expert",
      content: "Expert response",
      is_read: false
    )
    assert message.save, "valid message with expert role did not save"
  end

  test "valid message's attributes should all exist" do
    message = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Test message content",
      is_read: false
    )

    # Make sure message was saved
    assert message.persisted?, "Message was not saved"

    # Check that expected attributes exist and are not null
    assert_not_nil message.id, "id should not be null"
    assert_not_nil message.conversation_id, "conversation_id should not be null"
    assert_not_nil message.sender_id, "sender_id should not be null"
    assert_not_nil message.sender_role, "sender_role should not be null"
    assert_equal "initiator", message.sender_role, "sender_role should be 'initiator'"
    assert_not_nil message.content, "content should not be null"
    assert_equal "Test message content", message.content, "content should match"
    assert_not_nil message.is_read, "is_read should not be null"
    assert_equal false, message.is_read, "is_read should default to false"
    assert_not_nil message.created_at, "created_at should not be null"
    assert_not_nil message.updated_at, "updated_at should not be null"
  end

  test "should update conversation last_message_at after creation" do
    # Set initial last_message_at to nil or past time
    @conversation.update_column(:last_message_at, nil)
    
    initial_time = Time.current
    sleep(0.1) # Small delay to ensure different timestamps
    
    message = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )
    
    # Reload conversation to get updated last_message_at
    @conversation.reload
    
    assert_not_nil @conversation.last_message_at, "last_message_at should be set"
    assert_equal message.created_at.to_i, @conversation.last_message_at.to_i, 
                 "last_message_at should match message created_at"
  end

  test "set_sender_role sets initiator role when sender is conversation initiator" do
    message = Message.new(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Test message",
      is_read: false
    )
    
    message.set_sender_role
    assert_equal "initiator", message.sender_role, 
                 "sender_role should be set to 'initiator' when sender is initiator"
  end

  test "set_sender_role sets expert role when sender is assigned expert" do
    expert_user = User.create!(
      username: "expertuser2",
      password: "password123",
      password_confirmation: "password123"
    )
    
    expert_conversation = Conversation.create!(
      title: "Expert Conversation",
      initiator: @user,
      assigned_expert: expert_user,
      status: "active"
    )
    
    message = Message.new(
      conversation: expert_conversation,
      sender: expert_user,
      content: "Expert message",
      is_read: false
    )
    
    message.set_sender_role
    assert_equal "expert", message.sender_role,
                 "sender_role should be set to 'expert' when sender is assigned expert"
  end

  test "set_sender_role does not override existing sender_role" do
    message = Message.new(
      conversation: @conversation,
      sender: @user,
      sender_role: "expert",
      content: "Test message",
      is_read: false
    )
    
    message.set_sender_role
    assert_equal "expert", message.sender_role,
                 "sender_role should not be overridden if already set"
  end

  test "is_read can be set to true" do
    message = Message.create!(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Read message",
      is_read: true
    )
    
    assert_equal true, message.is_read, "is_read should be true"
  end

  test "is_read defaults to false when not specified" do
    message = Message.new(
      conversation: @conversation,
      sender: @user,
      sender_role: "initiator",
      content: "Test message"
    )
    message.is_read = false
    
    assert message.save, "message should save with is_read false"
    assert_equal false, message.is_read, "is_read should default to false"
  end
end
