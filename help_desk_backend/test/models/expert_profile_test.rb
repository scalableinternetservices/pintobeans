require "test_helper"

class ExpertProfileTest < ActiveSupport::TestCase

  test "expert profile that is missing user_id should not save" do
    expert1 = ExpertProfile.new(bio: "Placeholder text for bio")
    assert_not expert1.save, "invalid expert profile (missing user_id) was saved"
  end

  test "expert profile with non-unique user_id should not save" do

    user = User.new(
      username: "Kate1",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    assert user.save, "valid user did not save"

    expert2 = ExpertProfile.new(user_id: user.id, bio: "Placeholder text for expert2 bio")
    assert expert2.save, "valid expert (expert2) was not saved"

    expert3 = ExpertProfile.new(user_id: user.id, bio: "More placeholder text for expert3 bio")
    assert_not expert3.save, "invalid expert profile (duplicate user_id) was saved"
  end

  # note: bio and knowledge_base_links not required
  test "valid expert profile should save" do
    
    user = User.new(
      username: "Kate2",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    assert user.save, "valid user did not save"

    expert4 = ExpertProfile.new(
      user_id: user.id,
    )
    assert expert4.save, "valid expert profile did not save"
  end

  # test for foreign key
  test "expert profile must belong to a valid user" do

    user = User.new(
      username: "Kate3",
      password: "password123",
      password_confirmation: "password123",
      last_active_at: Time.current
    )

    assert user.save, "valid user did not save"

    # ExpertProfile with valid user_id should save
    valid_expert = ExpertProfile.new(user_id: user.id, bio: "Valid user")
    assert valid_expert.save, "expert profile with valid user did not save"

    # ExpertProfile with non-existent user_id should not save
    invalid_expert = ExpertProfile.new(user_id: 42403, bio: "Invalid user")
    assert_not invalid_expert.save, "expert profile with non-existent user_id was saved"
  end

end
