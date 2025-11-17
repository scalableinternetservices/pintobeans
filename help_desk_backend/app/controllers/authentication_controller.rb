class AuthenticationController < ApplicationController
    # Skip authentication for register & login
    skip_before_action :authenticate_user!, only: [:register, :login]
  
    # POST /auth/register
    def register
      user = User.new(user_params)
  
      if user.save
        ExpertProfile.create!(user_id: user.id)

        token = JwtService.encode(user)
        render json: {
          user: user_response(user),
          token: token
        }, status: :created
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end

    end
  
    # POST /auth/login
    def login
      user_params = params.require(:user).permit(:username, :password)
      user = User.find_by(username: user_params[:username])
    
      if user && user.authenticate(user_params[:password])
        user.update!(last_active_at: Time.current)
        token = JwtService.encode(user)
        render json: {
          user: user_response(user),
          token: token
        }, status: :ok
      else
        render json: { error: "Invalid username or password" }, status: :unauthorized
      end
    end
  
    # POST /auth/logout
    def logout
      # Optional if you're using stateless JWT (no server session)
      render json: { message: "Logged out successfully" }, status: :ok
    end
  
    # POST /auth/refresh
    def refresh
      if @current_user
        token = JwtService.encode(@current_user)
        render json: {
          user: user_response(@current_user),
          token: token
        }, status: :ok
      else
        render json: { error: "No session found" }, status: :unauthorized
      end
    end
  
    # GET /auth/me
    def me
      if @current_user
        render json: user_response(@current_user), status: :ok
      else
        render json: { error: "No session found" }, status: :unauthorized
      end
    end
  
    private
  
    # Strong params for registration
    def user_params
      params.require(:user).permit(:username, :password, :password_confirmation)
    end
  
    # Standard user JSON structure
    def user_response(user)
      {
        id: user.id,
        username: user.username,
        created_at: user.created_at.iso8601,
        last_active_at: user.last_active_at&.iso8601
      }
    end
end
  