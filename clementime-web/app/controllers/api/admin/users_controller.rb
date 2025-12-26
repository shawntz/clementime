module Api
  module Admin
    class UsersController < Api::BaseController
      before_action :authorize_admin!
      before_action :set_user, only: [ :show, :update, :destroy, :send_welcome_email, :send_slack_credentials ]

      def index
        users = User.where(role: params[:role] || "ta")
        users = users.where(username: params[:username]) if params[:username].present?
        users = users.order(:last_name, :first_name)

        render json: {
          users: users.map { |u| user_response(u) }
        }, status: :ok
      end

      def show
        render json: { user: user_response(@user) }, status: :ok
      end

      def create
        user = User.new(user_params)
        user.must_change_password = true

        if user.save
          render json: {
            message: "User created successfully",
            user: user_response(user)
          }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @user.update(user_params)
          render json: {
            message: "User updated successfully",
            user: user_response(@user)
          }, status: :ok
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @user.update(is_active: false)
        render json: { message: "User deactivated successfully" }, status: :ok
      end

      def send_welcome_email
        # Generate a one-time, time-limited token the user can use to set their password.
        # This avoids generating or storing a clear-text password.
        token = @user.respond_to?(:generate_password_reset_token!) ?
                  @user.generate_password_reset_token! :
                  nil

        @user.must_change_password = true

        if @user.save
          # Send email immediately (not using background job)
          begin
            UserMailer.welcome_email(@user, token).deliver_now
            render json: { message: "Welcome email sent successfully" }, status: :ok
          rescue => e
            Rails.logger.error "Email delivery failed: #{e.message}"
            render json: { errors: "Email delivery failed: #{e.message}" }, status: :unprocessable_entity
          end
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def send_slack_credentials
        # Generate a new temporary password using SecureRandom
        temp_password = generate_password

        # Note: Rails has_secure_password automatically hashes the password before storage
        # The password/password_confirmation are virtual attributes that trigger BCrypt hashing
        @user.password = temp_password
        @user.password_confirmation = temp_password
        @user.must_change_password = true

        if @user.save
          # Send Slack message with optional additional user IDs
          additional_user_ids = params[:include_user_ids] || []

          begin
            result = SlackNotifier.send_credentials(@user, temp_password, additional_user_ids)

            if result[:success]
              render json: { message: result[:message] }, status: :ok
            else
              render json: { errors: result[:error] }, status: :unprocessable_entity
            end
          ensure
            # Clear temporary password from memory
            temp_password = nil
          end
        else
          render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "User not found" }, status: :not_found
      end

      def user_params
        permitted = params.require(:user).permit(
          :username, :email, :password, :password_confirmation,
          :first_name, :last_name, :is_active, :location, :slack_id
        )
        # Only admins can set role, and it must be explicitly allowed
        permitted[:role] = params[:user][:role] if params[:user][:role].present? && params[:user][:role].in?([ "admin", "ta" ])
        # Convert empty slack_id to nil to avoid unique constraint issues
        permitted[:slack_id] = nil if permitted[:slack_id].blank?
        permitted
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
          location: user.location,
          slack_id: user.slack_id,
          is_active: user.is_active,
          must_change_password: user.must_change_password,
          sections_count: user.sections.count
        }
      end
    end
  end
end
