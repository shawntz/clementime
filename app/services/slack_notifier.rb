require "net/http"
require "uri"
require "json"

class SlackNotifier
  def self.send_credentials(user, temporary_password)
    slack_id = user.slack_id
    return { success: false, error: "User has no Slack ID configured" } unless slack_id.present?

    bot_token = SystemConfig.get(SystemConfig::SLACK_BOT_TOKEN)
    return { success: false, error: "Slack bot token not configured" } unless bot_token.present?

    login_url = "#{ENV['APP_HOST'] || 'http://localhost:5173'}/login"
    login_url = "https://#{login_url}" unless login_url.start_with?("http")

    message = {
      channel: slack_id,
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
end
