module Api
  module Admin
    class SlackController < Api::BaseController
      before_action :authorize_admin!

      def upload
        unless params[:file]
          return render json: { errors: "No file uploaded" }, status: :unprocessable_entity
        end

        matcher = SlackMatcher.new(params[:file].tempfile)

        if matcher.load_slack_users
          matcher.auto_match_by_email
          matcher.fuzzy_match_unmatched

          # Store slack users in session or cache for manual matching
          Rails.cache.write("slack_users_#{current_user.id}", matcher.slack_users, expires_in: 1.hour)

          render json: {
            message: "Slack roster uploaded successfully",
            matched_count: matcher.matched_count,
            total_slack_users: matcher.slack_users.count
          }, status: :ok
        else
          render json: {
            errors: matcher.errors
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def unmatched
        students = Student.slack_unmatched.includes(:section).map do |student|
          {
            id: student.id,
            full_name: student.full_name,
            email: student.email,
            section: student.section.code,
            slack_user_id: student.slack_user_id,
            slack_username: student.slack_username
          }
        end

        slack_users = Rails.cache.read("slack_users_#{current_user.id}") || []
        searchable_users = slack_users.map do |user|
          {
            value: user[:userid],
            label: "#{user[:fullname] || user[:displayname]} (#{user[:email]})",
            email: user[:email],
            username: user[:username]
          }
        end.sort_by { |u| u[:label] }

        render json: {
          unmatched_students: students,
          slack_users: searchable_users
        }, status: :ok
      end

      def match
        student = Student.find(params[:student_id])
        slack_users = Rails.cache.read("slack_users_#{current_user.id}") || []
        slack_user = slack_users.find { |u| u[:userid] == params[:slack_user_id] }

        unless slack_user
          return render json: { errors: "Slack user not found" }, status: :not_found
        end

        if student.update(
          slack_user_id: slack_user[:userid],
          slack_username: slack_user[:username],
          slack_matched: true
        )
          render json: {
            message: "Student matched successfully",
            student: {
              id: student.id,
              full_name: student.full_name,
              slack_username: student.slack_username
            }
          }, status: :ok
        else
          render json: { errors: student.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Student not found" }, status: :not_found
      end
    end
  end
end
