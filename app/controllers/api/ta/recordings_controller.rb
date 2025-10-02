module Api
  module Ta
    class RecordingsController < Api::BaseController
      before_action :set_exam_slot, only: [ :create ]

      def create
        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        # Verify TA has access to this section
        unless current_user.sections.exists?(id: @exam_slot.section_id)
          return render json: { errors: "Access denied to this section" }, status: :forbidden
        end

        # Check if recording already exists
        if @exam_slot.recording.present?
          return render json: { errors: "Recording already exists for this exam slot" }, status: :unprocessable_entity
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
            message: "Recording created successfully",
            recording: recording_response(recording)
          }, status: :created
        else
          render json: { errors: recording.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def upload
        recording = Recording.find(params[:id])

        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        # Verify TA owns this recording
        unless recording.ta_id == current_user.id
          return render json: { errors: "Access denied to this recording" }, status: :forbidden
        end

        unless params[:audio_data]
          return render json: { errors: "No audio data provided" }, status: :unprocessable_entity
        end

        # Decode base64 audio data
        audio_data = Base64.decode64(params[:audio_data])

        uploader = GoogleDriveUploader.new

        if uploader.upload_from_data(audio_data, recording)
          render json: {
            message: "Recording uploaded successfully",
            recording: recording_response(recording.reload)
          }, status: :ok
        else
          render json: {
            errors: uploader.errors
          }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Recording not found" }, status: :not_found
      rescue => e
        render json: { errors: [ e.message ] }, status: :internal_server_error
      end

      def test
        unless current_user.ta?
          return render json: { errors: "Access denied" }, status: :forbidden
        end

        begin
          # Create a test audio file (silent audio)
          test_audio_data = create_test_audio_data

          # Create a temporary test recording object
          uploader = GoogleDriveUploader.new

          # Test the upload without saving to database
          test_result = uploader.test_upload(test_audio_data, current_user)

          render json: {
            message: "Recording test completed successfully",
            test_result: test_result,
            status: "success"
          }, status: :ok
        rescue => e
          render json: {
            message: "Recording test failed",
            error: e.message
          }, status: :internal_server_error
        end
      end

      private

      def set_exam_slot
        @exam_slot = ExamSlot.find(params[:exam_slot_id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: "Exam slot not found" }, status: :not_found
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
