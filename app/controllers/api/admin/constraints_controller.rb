module Api
  module Admin
    class ConstraintsController < Api::BaseController
      before_action :authorize_admin!
      before_action :set_constraint, only: [:update, :destroy]

      def index
        student = Student.find(params[:student_id])
        constraints = student.constraints.active.order(created_at: :desc)

        render json: {
          constraints: constraints.map { |c| constraint_response(c) }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Student not found' }, status: :not_found
      end

      def create
        student = Student.find(params[:student_id])
        constraint = student.constraints.new(constraint_params)

        if constraint.save
          render json: {
            message: 'Constraint created successfully',
            constraint: constraint_response(constraint)
          }, status: :created
        else
          render json: { errors: constraint.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Student not found' }, status: :not_found
      end

      def update
        if @constraint.update(constraint_params)
          render json: {
            message: 'Constraint updated successfully',
            constraint: constraint_response(@constraint)
          }, status: :ok
        else
          render json: { errors: @constraint.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @constraint.update(is_active: false)
        render json: { message: 'Constraint deactivated successfully' }, status: :ok
      end

      private

      def set_constraint
        @constraint = Constraint.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { errors: 'Constraint not found' }, status: :not_found
      end

      def constraint_params
        params.require(:constraint).permit(
          :constraint_type,
          :constraint_value,
          :description,
          :is_active
        )
      end

      def constraint_response(constraint)
        {
          id: constraint.id,
          student_id: constraint.student_id,
          student_name: constraint.student.full_name,
          constraint_type: constraint.constraint_type,
          constraint_value: constraint.constraint_value,
          description: constraint.display_description,
          is_active: constraint.is_active
        }
      end
    end
  end
end
