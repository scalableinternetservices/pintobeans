module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    @current_user = current_user
    return if @current_user

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_user
    # Try JWT token from Authorization header
    auth_header = request.headers["Authorization"]
    if auth_header&.start_with?("Bearer ")
      token = auth_header.split(" ").last
      decoded = JwtService.decode(token)
      return User.find_by(id: decoded[:user_id]) if decoded
    end

    nil
  end
end

