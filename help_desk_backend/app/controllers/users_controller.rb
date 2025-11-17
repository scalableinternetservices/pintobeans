require_dependency Rails.root.join("app/services/jwt_service")

class UsersController < ApplicationController

  skip_before_action :authenticate_user!, only: [:register]
  
  def register
    @user = User.new(user_params)
    @user.last_active_at = Time.current

    if @user.save
      ExpertProfile.create!(user_id: user.id)

      token = JwtService.encode(@user)
      render json: {
        user: {
          id: @user.id,
          username: @user.username,
          created_at: @user.created_at,
          last_active_at: @user.last_active_at
        },
        token: token
      }, status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation)
  end
end
