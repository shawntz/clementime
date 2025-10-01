module Api
  module Ta
    class RecordingsController < Api::BaseController
      before_action :set_exam_slot, only: [:create]

      def create
        unless current_user.ta?
          return render json: { errors: 'Access denied' }, status: :forbidden
        end

        # Verify TA has access to this section
        unless current_user.sections.exists?(id: @exam_slot.section_id)
          return render json: { errors: 'Access denied to this section' }, status: :forbidden
        end

        # Check if recording already exists
        if @exam_slot.recording.present?
          return render json: { errors: 'Recording already exists for this exam slot' }, status: :unprocessable_entity
        end

        recording = Recording.new(
          exam_slot: @exam_slot,
          section: @exam_slot.section,
          student: @exam_slot.student,
          ta: current_user,
          recorded_at: Time.current
        )

        if recording.save
          render json: {
            message: 'Recording created successfully',
            recording: recording_response(recording)
          }, status: :created
        else
          render json: { errors: recording.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def upload
        recording = Recording.find(params[:id])

        unless current_user.ta?
          return render json: { errors: 'Access denied' }, status: :forbidden
        end

        # Verify TA owns this recording
        unless recording.ta_id == current_user.id
          return render json: { errors: 'Access denied to this recording' }, status: :forbidden
        end

        unless params[:audio_data]
          return render json: { errors: 'No audio data provided' }, status: :unprocessable_entity
        end

        # Decode base64 audio data
        audio_data = Base64.decode64(params[:audio_data])

        uploader = GoogleDriveUploader.new

        if uploader.upload_from_data(audio_data, recording)
          render json: {
            message: 'Recording uploaded successfully',
            recording: recording_response(recording.reload)
          }, status: :ok
        else
          render json: {
            errors: uploader.errors
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Recording not found' }, status: :not_found
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      private

      def set_exam_slot
        @exam_slot = ExamSlot.find(params[:exam_slot_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Exam slot not found' }, status: :not_found
      end

      def recording_response(recording)
        {
          id: recording.id,
          exam_slot_id: recording.exam_slot_id,
          student: {
            id: recording.student.id,
            full_name: recording.student.full_name
          },
          recorded_at: recording.recorded_at,
          uploaded_at: recording.uploaded_at,
          uploaded: recording.uploaded?,
          google_drive_file_id: recording.google_drive_file_id,
          recording_url: recording.recording_url
        }
      end
    end
  end
end
