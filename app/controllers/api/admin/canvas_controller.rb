module Api
  module Admin
    class CanvasController < Api::BaseController
      before_action :authorize_admin!

      def upload
        unless params[:file]
          return render json: { errors: 'No file uploaded' }, status: :unprocessable_entity
        end

        importer = CanvasRosterImporter.new(params[:file].tempfile)

        if importer.import
          render json: {
            message: 'Canvas roster imported successfully',
            success_count: importer.success_count,
            sections_created: importer.sections_created
          }, status: :ok
        else
          render json: {
            errors: importer.errors
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end
    end
  end
end
