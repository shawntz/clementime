require "google/apis/drive_v3"
require "googleauth"

module Api
  module Admin
    class GoogleAuthController < Api::BaseController
      before_action :authorize_admin!

      def authorize_url
        # Get OAuth client credentials from config
        client_id = SystemConfig.get("google_oauth_client_id")
        redirect_uri = "#{SystemConfig.get('base_url')}/api/admin/google_auth/callback"

        unless client_id.present?
          return render json: { error: "Google OAuth client ID not configured" }, status: :unprocessable_entity
        end

        # Build authorization URL
        auth_url = "https://accounts.google.com/o/oauth2/v2/auth?" + {
          client_id: client_id,
          redirect_uri: redirect_uri,
          response_type: "code",
          scope: Google::Apis::DriveV3::AUTH_DRIVE_FILE,
          access_type: "offline",
          prompt: "consent",
          state: current_user.id.to_s
        }.to_query

        render json: { authorization_url: auth_url }, status: :ok
      end

      def callback
        code = params[:code]
        state = params[:state]

        unless code.present?
          return redirect_to "/admin?google_auth_error=missing_code"
        end

        # Exchange code for tokens
        client_id = SystemConfig.get("google_oauth_client_id")
        client_secret = SystemConfig.get("google_oauth_client_secret")
        redirect_uri = "#{SystemConfig.get('base_url')}/api/admin/google_auth/callback"

        begin
          response = RestClient.post(
            "https://oauth2.googleapis.com/token",
            {
              code: code,
              client_id: client_id,
              client_secret: client_secret,
              redirect_uri: redirect_uri,
              grant_type: "authorization_code"
            }
          )

          tokens = JSON.parse(response.body)

          # Store tokens in system config
          SystemConfig.set("google_oauth_access_token", tokens["access_token"], config_type: "string")
          SystemConfig.set("google_oauth_refresh_token", tokens["refresh_token"], config_type: "string") if tokens["refresh_token"]
          SystemConfig.set("google_oauth_expires_at", (Time.current + tokens["expires_in"].to_i.seconds).to_s, config_type: "string")
          SystemConfig.set("google_oauth_authorized", true, config_type: "boolean")

          redirect_to "/admin?google_auth_success=true"
        rescue RestClient::ExceptionWithResponse => e
          Rails.logger.error("Google OAuth error: #{e.response}")
          redirect_to "/admin?google_auth_error=#{ERB::Util.url_encode(e.message)}"
        rescue => e
          Rails.logger.error("Google OAuth error: #{e.message}")
          redirect_to "/admin?google_auth_error=#{ERB::Util.url_encode(e.message)}"
        end
      end

      def status
        authorized = SystemConfig.get("google_oauth_authorized", false)
        expires_at = SystemConfig.get("google_oauth_expires_at")

        render json: {
          authorized: authorized,
          expires_at: expires_at
        }, status: :ok
      end

      def revoke
        SystemConfig.set("google_oauth_access_token", nil, config_type: "string")
        SystemConfig.set("google_oauth_refresh_token", nil, config_type: "string")
        SystemConfig.set("google_oauth_expires_at", nil, config_type: "string")
        SystemConfig.set("google_oauth_authorized", false, config_type: "boolean")

        render json: { message: "Google Drive authorization revoked" }, status: :ok
      end
    end
  end
end
