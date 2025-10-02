module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request
  end

  private

  def authenticate_request
    header = request.headers["Authorization"]
    header = header.split(" ").last if header

    begin
      @decoded = JsonWebToken.decode(header)
      @current_user = User.find(@decoded[:user_id]) if @decoded
    rescue ActiveRecord::RecordNotFound => e
      render json: { errors: "Unauthorized" }, status: :unauthorized
    rescue JWT::DecodeError => e
      render json: { errors: "Unauthorized" }, status: :unauthorized
    end

    render json: { errors: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def current_user
    @current_user
  end

  def authorize_admin!
    unless current_user&.admin?
      render json: { errors: "Forbidden - Admin access required" }, status: :forbidden
    end
  end
end
