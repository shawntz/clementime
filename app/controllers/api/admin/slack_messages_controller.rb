module Api
  module Admin
    class SlackMessagesController < Api::BaseController
      before_action :authorize_admin!

      # Send schedule messages to TAs for a specific exam and week type
      def send_ta_schedules
        exam_number = params[:exam_number].to_i
        week_type = params[:week_type] # 'odd' or 'even'

        if exam_number < 1 || exam_number > 5
          return render json: { errors: "Invalid exam number" }, status: :unprocessable_entity
        end

        unless %w[odd even].include?(week_type)
          return render json: { errors: "Invalid week type" }, status: :unprocessable_entity
        end

        bot_token = SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN)
        unless bot_token.present?
          return render json: { errors: "Slack bot token not configured" }, status: :unprocessable_entity
        end

        admin_slack_ids = SystemConfig.get("admin_slack_ids", "").split(",").map(&:strip).reject(&:blank?)

        # Get all TAs with sections
        tas = User.where(role: "ta").includes(:sections)
        results = []
        errors = []

        tas.each do |ta|
          next unless ta.slack_id.present?

          ta.sections.each do |section|
            # Get exam slots for this section (TA), exam, and week type
            # Note: exam_slots.section_id is the section they're SCHEDULED with (not their enrolled section)
            # This supports balanced TA scheduling where students can be scheduled with any TA
            exam_slots = ExamSlot.joins(:student)
                                .where(section: section, exam_number: exam_number, is_scheduled: true)
                                .where(students: { week_group: week_type })
                                .order(:start_time)

            next if exam_slots.empty?

            # Get distinct students from the exam slots
            students = Student.where(id: exam_slots.pluck(:student_id))

            schedule_list = exam_slots.map.with_index(1) do |slot, index|
              "#{index}. *#{slot.student.full_name}*\n🕐 #{slot.formatted_time_range}"
            end.join("\n\n")

            # Send message to TA in private channel
            message = build_ta_message_with_schedule(ta, section, exam_number, week_type, students.count, schedule_list)

            begin
              # Generate channel name from template
              channel_name = build_channel_name(ta, section, exam_number, week_type)

              # Create private channel with TA and admins
              user_ids_to_invite = ([ ta.slack_id ] + admin_slack_ids).compact.uniq
              channel_id = create_private_channel(bot_token, channel_name, user_ids_to_invite)

              if channel_id
                send_slack_message_to_channel(bot_token, channel_id, message)
                results << {
                  ta: ta.full_name,
                  section: section.name,
                  student_count: students.count,
                  channel_name: channel_name
                }
              else
                errors << "#{ta.full_name} (#{section.name}): Failed to create channel"
              end
            rescue => e
              errors << "#{ta.full_name} (#{section.name}): #{e.message}"
            end
          end
        end

        render json: {
          message: "TA schedules sent",
          sent_count: results.count,
          results: results,
          errors: errors
        }, status: :ok
      end

      # Send schedule messages to students for a specific exam and week type
      def send_student_schedules
        exam_number = params[:exam_number].to_i
        week_type = params[:week_type] # 'odd' or 'even'

        if exam_number < 1 || exam_number > 5
          return render json: { errors: "Invalid exam number" }, status: :unprocessable_entity
        end

        unless %w[odd even].include?(week_type)
          return render json: { errors: "Invalid week type" }, status: :unprocessable_entity
        end

        # Get all students with scheduled slots for this exam and week type
        exam_slots = ExamSlot.joins(:student)
                            .where(exam_number: exam_number, is_scheduled: true)
                            .where(students: { week_group: week_type, slack_matched: true })
                            .includes(:student, :section)

        results = []
        errors = []
        locked_count = 0

        bot_token = SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN)
        unless bot_token.present?
          return render json: { errors: "Slack bot token not configured" }, status: :unprocessable_entity
        end

        # Check if test mode is enabled
        test_mode = SystemConfig.get("slack_test_mode", false)
        test_user_id = SystemConfig.get("slack_test_user_id", "")
        super_admin_slack_id = SystemConfig.get("super_admin_slack_id", "")

        exam_slots.each do |slot|
          # Build message for student
          message = build_student_message(slot)

          begin
            # Build list of participants for MPDM
            participants = []

            if test_mode && test_user_id.present?
              # Test mode: send to test user instead of actual student
              participants << test_user_id
            else
              # Normal mode: send to actual student
              participants << slot.student.slack_user_id
            end

            # Add TA if they have a Slack ID
            ta = slot.section.ta
            participants << ta.slack_id if ta && ta.slack_id.present?

            # Add super admin if configured
            participants << super_admin_slack_id if super_admin_slack_id.present?

            # Remove duplicates and nils
            participants = participants.compact.uniq

            # Create MPDM if multiple participants, otherwise send DM
            channel = if participants.length > 1
              SlackNotifier.create_mpdm(bot_token, participants)
            else
              participants.first
            end

            unless channel
              raise "Failed to create conversation for #{slot.student.full_name}"
            end

            send_slack_message_to_channel(bot_token, channel, message)

            # Lock the slot after sending
            slot.update!(is_locked: true)
            locked_count += 1

            results << {
              student: slot.student.full_name,
              time: slot.formatted_time_range,
              locked: true,
              conversation_type: participants.length > 1 ? "MPDM" : "DM"
            }
          rescue => e
            errors << "#{slot.student.full_name}: #{e.message}"
          end
        end

        render json: {
          message: "Student schedules sent and locked",
          sent_count: results.count,
          locked_count: locked_count,
          results: results,
          errors: errors
        }, status: :ok
      end

      # Test recording functionality
      def test_recording
        begin
          # Create a test audio file (1 second of silence)
          test_audio_data = create_test_audio_data

          # Create uploader instance
          uploader = GoogleDriveUploader.new

          # Check if uploader has errors during initialization
          if uploader.errors.any?
            return render json: {
              message: "❌ Google Drive initialization failed",
              error: uploader.errors.join(", "),
              help: "Check System Config settings:\n- google_service_account_json (valid JSON credentials)\n- google_drive_folder_id (valid folder ID)"
            }, status: :ok
          end

          # Test the full workflow: upload and download
          test_result = uploader.test_upload(test_audio_data, current_user)

          if test_result[:success]
            render json: {
              message: "✅ Recording test completed successfully",
              details: {
                file_name: test_result[:file_name],
                file_url: test_result[:file_url],
                uploaded_size: "#{test_result[:uploaded_size]} bytes",
                downloaded_size: "#{test_result[:downloaded_size]} bytes",
                verification: test_result[:verification]
              },
              status: "success"
            }, status: :ok
          else
            render json: {
              message: "❌ Recording test failed",
              error: test_result[:error],
              details: test_result[:backtrace],
              help: "Check that Google Drive folder ID is configured correctly"
            }, status: :ok
          end
        rescue => e
          render json: {
            message: "Recording test failed",
            error: e.message,
            backtrace: e.backtrace.first(5)
          }, status: :internal_server_error
        end
      end

      def test_message
        message_type = params[:message_type]
        test_user_id = params[:test_user_id]
        admin_slack_ids = SystemConfig.get("admin_slack_ids", "").split(",").map(&:strip).reject(&:blank?)

        unless test_user_id.present?
          return render json: { error: "Test user ID is required" }, status: :unprocessable_entity
        end

        bot_token = SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN)
        unless bot_token.present?
          return render json: { error: "Slack bot token not configured" }, status: :unprocessable_entity
        end

        begin
          # Build test message with dummy data
          message_text = case message_type
          when "student"
            build_test_student_message
          when "ta"
            build_test_ta_message
          when "channel_name"
            # For channel name, just send it as a message
            channel_name = build_test_channel_name
            "🧪 Test Channel Name:\n`#{channel_name}`"
          else
            return render json: { error: "Invalid message type" }, status: :unprocessable_entity
          end

          # Validate message has content
          if message_text.blank? || message_text.strip.empty?
            return render json: { error: "Message template is empty. Please add content to the template." }, status: :unprocessable_entity
          end

          # Determine channel (MPDM or DM)
          channel = if admin_slack_ids.any?
            # Create MPDM with test user and admins
            all_user_ids = ([ test_user_id ] + admin_slack_ids).uniq
            SlackNotifier.create_mpdm(bot_token, all_user_ids)
          else
            # Send DM to test user only
            test_user_id
          end

          unless channel
            return render json: { error: "Failed to create Slack conversation" }, status: :internal_server_error
          end

          # Send message
          send_slack_test_message(bot_token, channel, message_text)

          render json: {
            message: "Test message sent successfully",
            sent_to: admin_slack_ids.any? ? "MPDM" : "DM",
            recipients: admin_slack_ids.any? ? ([ test_user_id ] + admin_slack_ids) : [ test_user_id ]
          }, status: :ok
        rescue => e
          Rails.logger.error("Test message error: #{e.message}")
          render json: { error: e.message }, status: :internal_server_error
        end
      end

      private

      def build_test_student_message
        template = SystemConfig.get("slack_student_message_template", "📝 Oral Exam Session for {{student_name}}\n\n📊 Exam Number: {{exam_number}}\n📅 Date: {{date}}\n⏰ Time: {{time}}\n📍 Location: {{location}}\n👤 Facilitator: {{ta_name}}\n\n📋 Course: {{course}} | 🎓 Term: {{term}}")

        template.gsub("{{student_name}}", "Jane Doe (TEST)")
                .gsub("{{exam_number}}", "1")
                .gsub("{{week}}", "1")
                .gsub("{{date}}", "Friday, October 10, 2025")
                .gsub("{{time}}", "1:30 PM - 1:37 PM")
                .gsub("{{location}}", SystemConfig.get("slack_exam_location", "Jordan Hall 420"))
                .gsub("{{ta_name}}", "John Smith")
                .gsub("{{course}}", SystemConfig.get("slack_course_name", "PSYCH 10 / STATS 60"))
                .gsub("{{term}}", SystemConfig.get("slack_term", "Fall 2025"))
      end

      def build_test_ta_message
        template = SystemConfig.get("slack_ta_message_template", "📋 {{ta_name}} - Oral Exam Session Schedule")

        schedule_list = "1. *Jane Doe*\n🕐 1:30 PM - 1:37 PM\n\n2. *John Smith*\n🕐 1:38 PM - 1:45 PM\n\n3. *Sarah Johnson*\n🕐 1:46 PM - 1:53 PM"

        template.gsub("{{ta_name}}", "Test TA")
                .gsub("{{exam_number}}", "1")
                .gsub("{{week}}", "1")
                .gsub("{{date}}", "Friday, October 10, 2025")
                .gsub("{{location}}", SystemConfig.get("slack_exam_location", "Jordan Hall 420"))
                .gsub("{{student_count}}", "3")
                .gsub("{{schedule_list}}", schedule_list)
                .gsub("{{ta_page_url}}", SystemConfig.get("base_url", "") + "/ta")
                .gsub("{{grade_form_url}}", "https://forms.gle/example")
                .gsub("{{course}}", SystemConfig.get("slack_course_name", "PSYCH 10 / STATS 60"))
                .gsub("{{term}}", SystemConfig.get("slack_term", "Fall 2025"))
      end

      def build_channel_name(ta, section, exam_number, week_type)
        template = SystemConfig.get("slack_channel_name_template", "{{course}}-oralexam-{{ta_name}}-week{{week}}-{{term}}")

        # Calculate week number (exam 1 = week 1-2, exam 2 = week 3-4, etc.)
        week_number = (exam_number - 1) * 2 + (week_type == "odd" ? 1 : 2)

        # Get actual config values and sanitize for Slack channel names
        course = SystemConfig.get("slack_course_name", "PSYCH 10").downcase.gsub(/\s+/, "").gsub(/[^a-z0-9\-]/, "-")
        term = SystemConfig.get("slack_term", "Fall 2025").downcase.gsub(/\s+/, "").gsub(/[^a-z0-9\-]/, "-")
        ta_name = ta.full_name.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "-")

        channel_name = template.gsub("{{course}}", course)
                               .gsub("{{ta_name}}", ta_name)
                               .gsub("{{week}}", week_number.to_s)
                               .gsub("{{term}}", term)
                               .downcase
                               .gsub(/[^a-z0-9\-]/, "-")
                               .gsub(/\-+/, "-")  # Replace multiple hyphens with single hyphen
                               .gsub(/^\-|\-$/, "")  # Remove leading/trailing hyphens

        # Slack channel names must be <= 80 characters
        channel_name[0...80]
      end

      def build_test_channel_name
        template = SystemConfig.get("slack_channel_name_template", "{{course}}-oral-exam-session-ta-{{ta_name}}-week{{week}}-{{term}}")

        # Get actual config values and sanitize for Slack channel names
        course = SystemConfig.get("slack_course_name", "PSYCH 10").downcase.gsub(/\s+/, "").gsub(/[^a-z0-9\-]/, "-")
        term = SystemConfig.get("slack_term", "Fall 2025").downcase.gsub(/\s+/, "").gsub(/[^a-z0-9\-]/, "-")

        template.gsub("{{course}}", course)
                .gsub("{{ta_name}}", "john-smith")
                .gsub("{{week}}", "1")
                .gsub("{{term}}", term)
                .downcase
                .gsub(/[^a-z0-9\-]/, "-")
      end

      def create_private_channel(bot_token, channel_name, user_ids_to_invite)
        require "net/http"
        require "uri"
        require "json"

        # Step 1: Create private channel
        uri = URI.parse("https://slack.com/api/conversations.create")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{bot_token}"
        request["Content-Type"] = "application/json"
        request.body = {
          name: channel_name,
          is_private: true
        }.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        result = JSON.parse(response.body)

        unless result["ok"]
          Rails.logger.error "Failed to create channel: #{result["error"]}"
          return nil
        end

        channel_id = result["channel"]["id"]

        # Step 2: Invite users to the channel
        if user_ids_to_invite.any?
          invite_uri = URI.parse("https://slack.com/api/conversations.invite")
          invite_request = Net::HTTP::Post.new(invite_uri)
          invite_request["Authorization"] = "Bearer #{bot_token}"
          invite_request["Content-Type"] = "application/json"
          invite_request.body = {
            channel: channel_id,
            users: user_ids_to_invite.join(",")
          }.to_json

          invite_response = Net::HTTP.start(invite_uri.hostname, invite_uri.port, use_ssl: true) do |http|
            http.request(invite_request)
          end

          invite_result = JSON.parse(invite_response.body)

          unless invite_result["ok"]
            Rails.logger.error "Failed to invite users to channel: #{invite_result["error"]}"
            # Channel was created but invite failed - still return channel_id
          end
        end

        channel_id
      rescue => e
        Rails.logger.error "Failed to create private channel: #{e.message}"
        nil
      end

      def send_slack_test_message(bot_token, channel, message_text)
        require "net/http"
        require "uri"
        require "json"

        message = {
          channel: channel,
          text: message_text
        }

        uri = URI.parse("https://slack.com/api/chat.postMessage")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{bot_token}"
        request["Content-Type"] = "application/json"
        request.body = message.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        result = JSON.parse(response.body)

        unless result["ok"]
          raise "Slack API error: #{result["error"] || "Unknown error"}"
        end

        result
      end

      def build_ta_message(ta, section, exam_number, week_type, student_count)
        template = SystemConfig.get("slack_ta_schedule_template", "")

        week_number = calculate_week_number(exam_number, week_type)

        template.gsub("{{ta_name}}", ta.full_name)
                .gsub("{{exam_number}}", exam_number.to_s)
                .gsub("{{week}}", week_number.to_s)
                .gsub("{{week_type}}", week_type.capitalize)
                .gsub("{{student_count}}", student_count.to_s)
                .gsub("{{ta_page_url}}", SystemConfig.get("slack_ta_page_url", ""))
                .gsub("{{grade_form_url}}", SystemConfig.get("slack_grade_form_url", ""))
                .gsub("{{course}}", SystemConfig.get("slack_course_name", ""))
                .gsub("{{term}}", SystemConfig.get("slack_term", ""))
      end

      def build_student_message(exam_slot)
        template = SystemConfig.get("slack_student_message_template", "")

        # Get TA for this section
        ta = exam_slot.section.ta
        ta_name = ta ? ta.full_name : "TBA"
        location = ta && ta.location.present? ? ta.location : "TBA"

        template.gsub("{{student_name}}", exam_slot.student.full_name)
                .gsub("{{exam_number}}", exam_slot.exam_number.to_s)
                .gsub("{{week}}", exam_slot.week_number.to_s)
                .gsub("{{date}}", exam_slot.date ? exam_slot.date.strftime("%A, %B %d, %Y") : "TBA")
                .gsub("{{time}}", exam_slot.formatted_time_range)
                .gsub("{{location}}", location)
                .gsub("{{ta_name}}", ta_name)
                .gsub("{{course}}", SystemConfig.get("slack_course_name", ""))
                .gsub("{{term}}", SystemConfig.get("slack_term", ""))
      end

      def send_slack_message_to_channel(bot_token, channel, message_text)
        require "net/http"
        require "uri"
        require "json"

        message = {
          channel: channel,
          text: message_text
        }

        uri = URI.parse("https://slack.com/api/chat.postMessage")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{bot_token}"
        request["Content-Type"] = "application/json"
        request.body = message.to_json

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        result = JSON.parse(response.body)

        unless result["ok"]
          raise "Slack API error: #{result["error"] || "Unknown error"}"
        end

        result
      end

      def build_ta_message_with_schedule(ta, section, exam_number, week_type, student_count, schedule_list)
        template = SystemConfig.get("slack_ta_message_template", "")
        week_number = calculate_week_number(exam_number, week_type)

        # Get exam date from exam_dates config or calculate it
        exam_date_key = "#{exam_number}_#{week_type == 'odd' ? 'odd' : 'even'}"
        exam_dates = SystemConfig.get("exam_dates", {})
        exam_date_str = exam_dates[exam_date_key]

        date_formatted = if exam_date_str
          Date.parse(exam_date_str).strftime("%A, %B %d, %Y")
        else
          "TBA"
        end

        # Get grade form URL for this exam
        grade_form_urls = SystemConfig.get("grade_form_urls", {})
        grade_form_url = grade_form_urls[exam_number.to_s] || grade_form_urls[exam_number] || "Not set"

        base_url = SystemConfig.get("base_url", "")
        ta_page_url = "#{base_url}/ta"

        template.gsub("{{ta_name}}", ta.full_name)
                .gsub("{{exam_number}}", exam_number.to_s)
                .gsub("{{week}}", week_number.to_s)
                .gsub("{{date}}", date_formatted)
                .gsub("{{location}}", SystemConfig.get("slack_exam_location", "TBA"))
                .gsub("{{student_count}}", student_count.to_s)
                .gsub("{{schedule_list}}", schedule_list)
                .gsub("{{ta_page_url}}", ta_page_url)
                .gsub("{{grade_form_url}}", grade_form_url)
                .gsub("{{course}}", SystemConfig.get("slack_course_name", ""))
                .gsub("{{term}}", SystemConfig.get("slack_term", ""))
      end

      def calculate_week_number(exam_number, week_type)
        # Calculate week number based on exam number and week type
        # Odd weeks: 1, 3, 5, 7, 9
        # Even weeks: 2, 4, 6, 8, 10
        base = (exam_number - 1) * 2
        week_type == "odd" ? base + 1 : base + 2
      end

      def create_test_audio_data
        # Create a minimal valid WAV file header (1 second of silence at 44.1kHz, 16-bit, mono)
        sample_rate = 44100
        bits_per_sample = 16
        num_channels = 1
        duration = 1 # seconds
        num_samples = sample_rate * duration

        data_size = num_samples * num_channels * (bits_per_sample / 8)
        file_size = 36 + data_size

        wav_header = [
          "RIFF",
          [ file_size ].pack("V"),
          "WAVE",
          "fmt ",
          [ 16 ].pack("V"),  # fmt chunk size
          [ 1 ].pack("v"),   # audio format (PCM)
          [ num_channels ].pack("v"),
          [ sample_rate ].pack("V"),
          [ sample_rate * num_channels * bits_per_sample / 8 ].pack("V"), # byte rate
          [ num_channels * bits_per_sample / 8 ].pack("v"), # block align
          [ bits_per_sample ].pack("v"),
          "data",
          [ data_size ].pack("V")
        ].join

        # Silent audio data (all zeros)
        audio_data = "\x00" * data_size

        wav_header + audio_data
      end
    end
  end
end
