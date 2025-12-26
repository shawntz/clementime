module Api
  class AuthController < ApplicationController
    before_action :authenticate_request, only: [ :current_user, :change_password, :logout ]

    def login
      user = User.find_by(username: params[:username])

      if user&.authenticate(params[:password])
        if user.is_active
          token = JsonWebToken.encode(user_id: user.id)
          render json: {
            token: token,
            user: user_response(user)
          }, status: :ok
        else
          render json: { errors: "Account is inactive" }, status: :unauthorized
        end
      else
        render json: { errors: "Invalid username or password" }, status: :unauthorized
      end
    end

    def current_user
      render json: { user: user_response(@current_user) }, status: :ok
    end

    def change_password
      if @current_user.authenticate(params[:current_password])
        if @current_user.update(
          password: params[:new_password],
          password_confirmation: params[:new_password_confirmation],
          must_change_password: false
        )
          render json: { message: "Password changed successfully" }, status: :ok
        else
          render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
        end
      else
        render json: { errors: "Current password is incorrect" }, status: :unauthorized
      end
    end

    def logout
      # With JWT, logout is handled client-side by removing the token
      render json: { message: "Logged out successfully" }, status: :ok
    end

    def forgot_password
      user = User.find_by(email: params[:email])

      if user
        user.generate_password_reset_token!
        UserMailer.password_reset(user).deliver_now
        render json: { message: "Password reset instructions have been sent to your email" }, status: :ok
      else
        # Don't reveal if the email exists or not for security reasons
        render json: { message: "If an account with that email exists, password reset instructions have been sent" }, status: :ok
      end
    rescue StandardError => e
      Rails.logger.error("Password reset error: #{e.message}")
      render json: { errors: "Unable to process password reset request" }, status: :internal_server_error
    end

    def reset_password
      user = User.find_by(reset_password_token: params[:token])

      if user.nil?
        render json: { errors: "Invalid or expired reset token" }, status: :unprocessable_entity
        return
      end

      unless user.password_reset_token_valid?
        render json: { errors: "Reset token has expired. Please request a new one." }, status: :unprocessable_entity
        return
      end

      if user.update(
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        must_change_password: false
      )
        user.clear_password_reset_token!
        render json: { message: "Password has been reset successfully" }, status: :ok
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    rescue StandardError => e
      Rails.logger.error("Password reset error: #{e.message}")
      render json: { errors: "Unable to reset password" }, status: :internal_server_error
    end

    private

    def authenticate_request
      header = request.headers["Authorization"]
      header = header.split(" ").last if header

      begin
        @decoded = JsonWebToken.decode(header)
        @current_user = User.find(@decoded[:user_id]) if @decoded
      rescue ActiveRecord::RecordNotFound, JWT::DecodeError => e
        render json: { errors: "Unauthorized" }, status: :unauthorized
        return
      end

      render json: { errors: "Unauthorized" }, status: :unauthorized unless @current_user
    end

    def user_response(user)
      {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name,
        full_name: user.full_name,
        must_change_password: user.must_change_password,
        is_active: user.is_active
      }
    end
  end
end
