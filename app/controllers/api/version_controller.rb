module Api
  class VersionController < ApplicationController
    skip_before_action :authenticate_request, only: [ :show ], raise: false

    def show
      version = nil
      release_date = nil

      # Try to read version from VERSION file (if it exists)
      version_file = Rails.root.join("VERSION")
      if File.exist?(version_file)
        version = File.read(version_file).strip
      end

      # Fallback: try to get from git tag
      if version.nil? || version.empty?
        begin
          version = `git describe --tags --abbrev=0 2>/dev/null`.strip
          version = "v1.0.0" if version.empty?
        rescue => e
          version = "v1.0.0"
        end
      end

      # Try to get release date from git tag
      begin
        tag_date = `git log -1 --format=%ai #{version} 2>/dev/null`.strip
        release_date = tag_date unless tag_date.empty?
      rescue => e
        Rails.logger.debug("Could not get release date: #{e.message}")
      end

      render json: {
        version: version,
        release_date: release_date
      }, status: :ok
    end
  end
end
