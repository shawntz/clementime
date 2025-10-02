class ApplicationController < ActionController::API
  def index
    index_path = Rails.root.join("public", "index.html")
    if File.exist?(index_path)
      render file: index_path, layout: false
    else
      render json: { error: "index.html not found at #{index_path}" }, status: 500
    end
  end
end
