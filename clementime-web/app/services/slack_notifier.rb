require "net/http"
require "uri"
require "json"

class SlackNotifier
  def self.send_credentials(user, temporary_password, additional_user_ids = [])
    slack_id = user.slack_id
    return { success: false, error: "User has no Slack ID configured" } unless slack_id.present?

    bot_token = SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN)
    return { success: false, error: "Slack bot token not configured" } unless bot_token.present?

    # Check if test mode is enabled
    test_mode = SystemConfig.get("slack_test_mode", false)
    test_user_id = SystemConfig.get("slack_test_user_id", "")

    # Get Slack IDs for additional users
    additional_slack_ids = []
    if additional_user_ids.any?
      additional_users = User.where(id: additional_user_ids).where.not(slack_id: nil)
      additional_slack_ids = additional_users.pluck(:slack_id)
    end

    # Get TA's Slack ID if this is a student getting credentials from their TA
    ta_slack_id = user.respond_to?(:section) && user.section&.ta&.slack_id

    # Get super admin Slack ID
    super_admin_slack_id = SystemConfig.get("super_admin_slack_id", "")

    # Build list of participants
    if test_mode && test_user_id.present?
      # Test mode: MPDM with TA + selected additional users (NOT the actual student)
      participants = []
      participants << ta_slack_id if ta_slack_id.present?
      participants += additional_slack_ids if additional_slack_ids.any?
      participants << super_admin_slack_id if super_admin_slack_id.present?
      participants << test_user_id # Include test user
      participants = participants.compact.uniq

      # If only test user, send DM to test user
      participants = [ test_user_id ] if participants.empty?
    else
      # Normal mode: user + selected additional users + TA + super admin
      participants = [ slack_id ]
      participants += additional_slack_ids if additional_slack_ids.any?
      participants << ta_slack_id if ta_slack_id.present?
      participants << super_admin_slack_id if super_admin_slack_id.present?
      participants = participants.compact.uniq
    end

    # If we have multiple participants, create an MPDM, otherwise use DM
    channel = if participants.length > 1
      create_mpdm(bot_token, participants)
    else
      slack_id
    end

    unless channel
      error_msg = "Failed to create conversation with #{participants.length} participants. Check Rails logs for details."
      return { success: false, error: error_msg }
    end

    login_base = ENV["APP_HOST"] || "http://localhost:5173"
    login_base = "https://#{login_base}" unless login_base.start_with?("http")
    login_url = "#{login_base}/login?username=#{CGI.escape(user.username)}"

    message = {
      channel: channel,
      text: "🍊 Welcome to Clementime!",
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🍊 Welcome to Clementime!",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "Hi #{user.first_name}! Your account has been created for the Clementime Oral Exam Management system."
          }
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Username:*\n`#{user.username}`"
            },
            {
              type: "mrkdwn",
              text: "*Temporary Password:*\n`#{temporary_password}`"
            }
          ]
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "⚠️ *Important:* You will be required to change your password on first login."
          }
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "Login to Clementime"
              },
              url: login_url,
              style: "primary"
            }
          ]
        }
      ]
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

    if result["ok"]
      { success: true, message: "Credentials sent to Slack successfully" }
    else
      { success: false, error: result["error"] || "Unknown Slack API error" }
    end
  rescue => e
    { success: false, error: e.message }
  end

  private

  def self.create_mpdm(bot_token, user_ids)
    # Use conversations.open to create an MPDM
    uri = URI.parse("https://slack.com/api/conversations.open")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{bot_token}"
    request["Content-Type"] = "application/json"
    request.body = { users: user_ids.join(",") }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)
    if result["ok"]
      result["channel"]["id"]
    else
      error_msg = "Failed to create MPDM: #{result["error"] || "Unknown error"}"
      Rails.logger.error "#{error_msg} - User IDs: #{user_ids.inspect}"
      Rails.logger.error "Full response: #{result.inspect}"
      nil
    end
  rescue => e
    Rails.logger.error "Failed to create MPDM: #{e.message}"
    nil
  end
end
