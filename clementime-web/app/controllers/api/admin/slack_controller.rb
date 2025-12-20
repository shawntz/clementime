module Api
  module Admin
    class SlackController < Api::BaseController
      before_action :authorize_admin!

      def upload
        Rails.logger.info "SlackController#upload called by user #{current_user&.id}"

        unless params[:file]
          Rails.logger.warn "Upload attempted without file"
          return render json: { errors: "No file uploaded" }, status: :unprocessable_entity
        end

        Rails.logger.info "Processing Slack roster file: #{params[:file].original_filename}"

        matcher = SlackMatcher.new(params[:file].tempfile)

        if matcher.load_slack_users
          Rails.logger.info "Loaded #{matcher.slack_users.count} Slack users from CSV"

          matcher.auto_match_by_email
          Rails.logger.info "Auto-matched #{matcher.matched_count} students by email"

          matcher.fuzzy_match_unmatched
          Rails.logger.info "Completed fuzzy matching"

          # Store slack users in session or cache for manual matching
          Rails.cache.write("slack_users_#{current_user.id}", matcher.slack_users, expires_in: 1.hour)
          Rails.logger.info "Cached Slack users for user #{current_user.id}"

          render json: {
            message: "Slack roster uploaded successfully",
            matched_count: matcher.matched_count,
            total_slack_users: matcher.slack_users.count
          }, status: :ok
        else
          Rails.logger.error "Failed to load Slack users: #{matcher.errors.join(', ')}"
          render json: {
            errors: matcher.errors
          }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Upload error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def unmatched
        Rails.logger.info "SlackController#unmatched called by user #{current_user&.id}"

        begin
          students = Student.slack_unmatched.includes(:section).map do |student|
            {
              id: student.id,
              full_name: student.full_name,
              email: student.email,
              section: student.section&.code || "N/A",
              slack_user_id: student.slack_user_id,
              slack_username: student.slack_username
            }
          end

          Rails.logger.info "Found #{students.count} unmatched students"
        rescue => e
          Rails.logger.error "Error mapping unmatched students: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
          raise
        end

        begin
          slack_users = Rails.cache.read("slack_users_#{current_user.id}")
          if slack_users.nil?
            Rails.logger.info "No cached slack users found for user #{current_user.id}"
            slack_users = []
          else
            Rails.logger.info "Found #{slack_users.count} cached slack users"
          end

          searchable_users = slack_users.map do |user|
            next if user.nil? || user[:userid].nil?

            {
              value: user[:userid],
              label: "#{user[:fullname] || user[:displayname]} (#{user[:email] || 'no-email'})",
              email: user[:email],
              username: user[:username]
            }
          end.compact.sort_by { |u| u[:label] }
        rescue => e
          Rails.logger.error "Error processing slack users cache: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
          raise
        end

        render json: {
          unmatched_students: students,
          slack_users: searchable_users
        }, status: :ok
      rescue => e
        Rails.logger.error "Unmatched students error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { errors: [ e.message ] }, status: :internal_server_error
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
