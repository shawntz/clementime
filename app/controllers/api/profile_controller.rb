module Api
  class ProfileController < Api::BaseController
    include Authenticable

    before_action :authenticate_request

    def show
      render json: {
        user: user_response(current_user)
      }, status: :ok
    end

    def update
      # Check if username is being changed and if it's already taken
      if params[:username] && params[:username] != current_user.username
        if User.where(username: params[:username]).where.not(id: current_user.id).exists?
          render json: { errors: [ "Username is already taken" ] }, status: :unprocessable_entity
          return
        end
      end

      update_params = {}
      update_params[:username] = params[:username] if params[:username].present?
      update_params[:first_name] = params[:first_name] if params[:first_name].present?
      update_params[:last_name] = params[:last_name] if params[:last_name].present?
      update_params[:email] = params[:email] if params[:email].present?
      update_params[:location] = params[:location] if params.key?(:location)

      if current_user.update(update_params)
        render json: {
          message: "Profile updated successfully",
          user: user_response(current_user)
        }, status: :ok
      else
        render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update_password
      unless current_user.authenticate(params[:current_password])
        render json: { errors: [ "Current password is incorrect" ] }, status: :unprocessable_entity
        return
      end

      if params[:new_password] != params[:password_confirmation]
        render json: { errors: [ "New password and confirmation do not match" ] }, status: :unprocessable_entity
        return
      end

      if current_user.update(
        password: params[:new_password],
        password_confirmation: params[:password_confirmation],
        must_change_password: false
      )
        render json: { message: "Password updated successfully" }, status: :ok
      else
        render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def user_response(user)
      {
        id: user.id,
        username: user.username,
        email: user.email,
        role: user.role,
        first_name: user.first_name,
        last_name: user.last_name,
        full_name: user.full_name,
        location: user.location,
        is_active: user.is_active
      }
    end
  end
end
