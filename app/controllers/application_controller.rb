class ApplicationController < ActionController::API
  def index
    index_path = Rails.root.join("public", "index.html")
    public_dir = Rails.root.join("public")

    if File.exist?(index_path)
      Rails.logger.info "Serving index.html from #{index_path}"
      render file: index_path, layout: false
    else
      error_info = {
        error: "index.html not found",
        index_path: index_path.to_s,
        public_exists: Dir.exist?(public_dir),
        public_files: Dir.exist?(public_dir) ? Dir.entries(public_dir) : []
      }
      Rails.logger.error "Missing index.html: #{error_info.inspect}"
      render json: error_info, status: 500
    end
  end
end
