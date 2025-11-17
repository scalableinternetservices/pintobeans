class HealthController < ApplicationController

  skip_before_action :authenticate_user!, only: [:show]

  # GET /health
  def show
    render json: { status: "ok", timestamp: Time.now.utc.iso8601 }
  end
end