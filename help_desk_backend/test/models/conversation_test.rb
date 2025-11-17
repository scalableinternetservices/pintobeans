require "test_helper"

class ConversationTest < ActiveSupport::TestCase
    def setup
        @user = User.create!(
            username: "testuser",
            password: "password123",
            password_confirmation: "password123"
        )
    end

    test "should not save conversation without title" do
        conversation = Conversation.new(
            initiator: @user,
        )
        assert_not conversation.save, "invalid conversation (no title) was saved"
    end

    test "should save valid conversation" do
        conversation = Conversation.new(
            title: "Test Conversation",
            initiator: @user,
            status: "waiting"
        )
        assert conversation.save, "valid conversation did not save"
    end

    test "valid conversation's attributes should all exist" do
        conversation = Conversation.create(
            title: "Test Conversation",
            initiator: @user,
            status: "waiting"
        )
        assert conversation.persisted?, "Conversation was not saved"
        assert_not_nil conversation.id, "id should not be null"
        assert_not_nil conversation.title, "title should not be null"
        assert_not_nil conversation.initiator, "initiator should not be null"
        assert_not_nil conversation.status, "status should not be null"
    end
end