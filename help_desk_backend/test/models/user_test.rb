require "test_helper"

class UserTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "should not save user without username" do
    user = User.new(password: "password123")
    assert_not user.save, "invalid user (no username) was saved"
  end

  test "should not save user without password" do
    user = User.new(username: "KateLarrick")
    assert_not user.save, "invalid user (no password) was saved"
  end

  test "should save valid user" do
    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.save, "valid user did not save"
  end

  test "valid user's attributes should all exist" do

    user = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    # Make sure user was saved
    assert user.save, "User was not saved"

    # Check that expected attributes exist and are not null
    assert_not_nil user.id, "id should not be null"
    assert_not_nil user.username, "username should not be null"
    assert_not_nil user.password_digest, "password_digest should not be null"
    assert_not_nil user.last_active_at, "last_active_at should not be null"
    assert_not_nil user.created_at, "created_at should not be null"
    assert_not_nil user.updated_at, "updated_at should not be null"
  end

  test "should not save two users with the same username" do
    
    user1 = User.new(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    assert user1.save, "User 1 (valid) was not saved"

    user2 = User.create(
      username: "KateLarrick",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    assert_not user2.save, "invalid user (duplicate username) was saved"
  end

end
