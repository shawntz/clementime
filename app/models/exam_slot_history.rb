class ExamSlotHistory < ApplicationRecord
  belongs_to :exam_slot
  belongs_to :student
  belongs_to :section
end
