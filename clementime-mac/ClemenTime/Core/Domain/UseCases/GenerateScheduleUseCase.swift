//
//  GenerateScheduleUseCase.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//  Ported from Rails schedule_generator.rb (697 lines)
//

import Foundation

struct GenerateScheduleInput {
    let courseId: UUID
    let startingFromExam: Int? // nil = regenerate all, n = regenerate from exam n onwards
}

class GenerateScheduleUseCase {
    private let courseRepository: CourseRepository
    private let cohortRepository: CohortRepository
    private let studentRepository: StudentRepository
    private let sectionRepository: SectionRepository
    private let examSessionRepository: ExamSessionRepository
    private let constraintRepository: ConstraintRepository
    private let scheduleRepository: ScheduleRepository

    init(
        courseRepository: CourseRepository,
        cohortRepository: CohortRepository,
        studentRepository: StudentRepository,
        sectionRepository: SectionRepository,
        examSessionRepository: ExamSessionRepository,
        constraintRepository: ConstraintRepository,
        scheduleRepository: ScheduleRepository
    ) {
        self.courseRepository = courseRepository
        self.cohortRepository = cohortRepository
        self.studentRepository = studentRepository
        self.sectionRepository = sectionRepository
        self.examSessionRepository = examSessionRepository
        self.constraintRepository = constraintRepository
        self.scheduleRepository = scheduleRepository
    }

    func execute(input: GenerateScheduleInput) async throws -> ScheduleResult {
        // 1. Load course and validate
        guard let course = try await courseRepository.fetchCourse(id: input.courseId) else {
            throw UseCaseError.courseNotFound
        }

        // 2. Load cohorts, students, sections, exam sessions, constraints
        let cohorts = try await cohortRepository.fetchCohorts(courseId: input.courseId)
        let students = try await studentRepository.fetchStudents(courseId: input.courseId)
        let sections = try await sectionRepository.fetchSections(courseId: input.courseId)
        let examSessions = try await examSessionRepository.fetchExamSessions(courseId: input.courseId)

        guard !cohorts.isEmpty else {
            throw UseCaseError.invalidInput
        }

        // 3. Load constraints for all students
        var studentConstraints: [UUID: [Constraint]] = [:]
        for student in students {
            let constraints = try await constraintRepository.fetchActiveConstraints(studentId: student.id)
            studentConstraints[student.id] = constraints
        }

        // 4. Assign cohorts to students without one (respecting week_preference constraints)
        let updatedStudents = try await assignCohorts(
            students: students,
            cohorts: cohorts,
            constraints: studentConstraints
        )

        // 5. Determine which exams to generate
        let startExam = input.startingFromExam ?? 1
        let examNumbers = Array(startExam...course.totalExams)

        // 6. Generate slots
        var generatedCount = 0
        var unscheduledCount = 0
        var errors: [String] = []

        for examNumber in examNumbers {
            // Find the exam session for this exam number
            guard let examSession = examSessions.first(where: { $0.examNumber == examNumber }) else {
                errors.append("Exam session not found for exam \(examNumber)")
                continue
            }

            // Generate slots for each cohort
            for cohort in cohorts {
                // Get students in this cohort
                let cohortStudents = updatedStudents.filter { $0.cohortId == cohort.id }

                // Determine exam date for this cohort
                let examDate = cohort.weekType == .odd ? examSession.oddWeekDate : examSession.evenWeekDate

                // Generate slots for this cohort
                let result = try await generateCohortSlots(
                    students: cohortStudents,
                    cohort: cohort,
                    examSession: examSession,
                    examDate: examDate,
                    course: course,
                    constraints: studentConstraints,
                    sections: sections
                )

                generatedCount += result.scheduled
                unscheduledCount += result.unscheduled
                errors.append(contentsOf: result.errors)
            }
        }

        return ScheduleResult(
            scheduledCount: generatedCount,
            unscheduledCount: unscheduledCount,
            errors: errors
        )
    }

    // MARK: - Private Methods

    private func assignCohorts(
        students: [Student],
        cohorts: [Cohort],
        constraints: [UUID: [Constraint]]
    ) async throws -> [Student] {
        var updatedStudents: [Student] = []

        for var student in students {
            // Check if student has a week_preference constraint
            if let studentConstraints = constraints[student.id],
               let weekPreference = studentConstraints.first(where: { $0.constraintType == .weekPreference }) {
                // Find cohort matching the preference
                if let preferredCohort = cohorts.first(where: {
                    $0.weekType.rawValue == weekPreference.constraintValue
                }) {
                    if student.cohortId != preferredCohort.id {
                        student.cohortId = preferredCohort.id
                        try await studentRepository.updateStudent(student)
                    }
                }
            } else if student.cohortId == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
                // Student has no cohort assigned - assign randomly
                let randomCohort = cohorts.randomElement()!
                student.cohortId = randomCohort.id
                try await studentRepository.updateStudent(student)
            }

            updatedStudents.append(student)
        }

        return updatedStudents
    }

    private func generateCohortSlots(
        students: [Student],
        cohort: Cohort,
        examSession: ExamSession,
        examDate: Date,
        course: Course,
        constraints: [UUID: [Constraint]],
        sections: [Section]
    ) async throws -> (scheduled: Int, unscheduled: Int, errors: [String]) {
        var scheduled = 0
        var unscheduled = 0
        var errors: [String] = []

        // Group students by section
        let studentsBySection = Dictionary(grouping: students) { $0.sectionId }

        for (sectionId, sectionStudents) in studentsBySection {
            guard let section = sections.first(where: { $0.id == sectionId }) else {
                continue
            }

            // Prioritize students by constraint type
            let orderedStudents = prioritizeStudents(
                sectionStudents,
                constraints: constraints,
                seed: examSession.examNumber
            )

            // Parse start and end times
            let calendar = Calendar.current
            let baseDate = Date(timeIntervalSince1970: 0) // Reference date for times
            let startTimeComponents = parseTime(examSession.startTime)
            let endTimeComponents = parseTime(examSession.endTime)

            guard var currentTime = calendar.date(bySettingHour: startTimeComponents.hour,
                                                   minute: startTimeComponents.minute,
                                                   second: 0,
                                                   of: baseDate),
                  let endTime = calendar.date(bySettingHour: endTimeComponents.hour,
                                              minute: endTimeComponents.minute,
                                              second: 0,
                                              of: baseDate) else {
                errors.append("Failed to parse exam times for exam \(examSession.examNumber)")
                continue
            }

            // Load existing slots to check for locked slots
            let existingSlots = try await scheduleRepository.fetchExamSlots(
                courseId: course.id,
                examNumber: examSession.examNumber
            )

            for student in orderedStudents {
                // Check if student has existing locked slot
                if let existingSlot = existingSlots.first(where: { $0.studentId == student.id && $0.isLocked }) {
                    // Skip but advance time to avoid overlap
                    if existingSlot.isScheduled {
                        let slotEndWithBuffer = existingSlot.endTime.addingTimeInterval(
                            TimeInterval(examSession.bufferMinutes * 60)
                        )
                        if slotEndWithBuffer > currentTime {
                            currentTime = slotEndWithBuffer
                        }
                    }
                    continue
                }

                // Calculate slot end time
                let slotEndTime = currentTime.addingTimeInterval(
                    TimeInterval(examSession.durationMinutes * 60)
                )

                // Check if we have time remaining
                if slotEndTime > endTime {
                    // Create unscheduled slot
                    try await createUnscheduledSlot(
                        studentId: student.id,
                        sectionId: section.id,
                        examSession: examSession,
                        courseId: course.id
                    )
                    unscheduled += 1
                    continue
                }

                // Combine exam date with time
                let actualStartTime = combineDateTime(date: examDate, time: currentTime)
                let actualEndTime = combineDateTime(date: examDate, time: slotEndTime)

                // Check constraints
                if !canScheduleStudent(
                    student: student,
                    constraints: constraints[student.id] ?? [],
                    date: examDate,
                    startTime: actualStartTime,
                    endTime: actualEndTime
                ) {
                    // Create unscheduled slot
                    try await createUnscheduledSlot(
                        studentId: student.id,
                        sectionId: section.id,
                        examSession: examSession,
                        courseId: course.id
                    )
                    unscheduled += 1
                    continue
                }

                // Create scheduled slot
                let slot = ExamSlot(
                    id: UUID(),
                    courseId: course.id,
                    studentId: student.id,
                    sectionId: section.id,
                    examSessionId: examSession.id,
                    date: examDate,
                    startTime: actualStartTime,
                    endTime: actualEndTime,
                    isScheduled: true,
                    isLocked: false,
                    notes: nil
                )

                try await scheduleRepository.updateExamSlot(slot)
                scheduled += 1

                // Advance time for next student
                currentTime = slotEndTime.addingTimeInterval(
                    TimeInterval(examSession.bufferMinutes * 60)
                )
            }
        }

        return (scheduled, unscheduled, errors)
    }

    private func prioritizeStudents(
        _ students: [Student],
        constraints: [UUID: [Constraint]],
        seed: Int
    ) -> [Student] {
        // Group students by constraint priority
        var timeBefore: [Student] = []
        var timeAfter: [Student] = []
        var otherConstraints: [Student] = []
        var noConstraints: [Student] = []

        for student in students {
            let studentConstraints = constraints[student.id] ?? []

            let hasTimeBefore = studentConstraints.contains { $0.constraintType == .timeBefore }
            let hasTimeAfter = studentConstraints.contains { $0.constraintType == .timeAfter }
            let hasOther = studentConstraints.contains {
                $0.constraintType == .specificDate || $0.constraintType == .excludeDate
            }

            if hasTimeBefore {
                timeBefore.append(student)
            } else if hasTimeAfter {
                timeAfter.append(student)
            } else if hasOther {
                otherConstraints.append(student)
            } else {
                noConstraints.append(student)
            }
        }

        // Shuffle within each group for fairness
        return timeBefore.shuffled() +
               timeAfter.shuffled() +
               otherConstraints.shuffled() +
               noConstraints.shuffled()
    }

    private func canScheduleStudent(
        student: Student,
        constraints: [Constraint],
        date: Date,
        startTime: Date,
        endTime: Date
    ) -> Bool {
        for constraint in constraints where constraint.isActive {
            switch constraint.constraintType {
            case .timeBefore:
                // Student must start BEFORE this time
                let maxTime = parseConstraintTime(constraint.constraintValue)
                let startTimeComponents = Calendar.current.dateComponents([.hour, .minute], from: startTime)
                let maxTimeComponents = parseTime(maxTime)

                if startTimeComponents.hour! > maxTimeComponents.hour ||
                   (startTimeComponents.hour! == maxTimeComponents.hour &&
                    startTimeComponents.minute! >= maxTimeComponents.minute) {
                    return false
                }

            case .timeAfter:
                // Student must start AFTER this time
                let minTime = parseConstraintTime(constraint.constraintValue)
                let startTimeComponents = Calendar.current.dateComponents([.hour, .minute], from: startTime)
                let minTimeComponents = parseTime(minTime)

                if startTimeComponents.hour! < minTimeComponents.hour ||
                   (startTimeComponents.hour! == minTimeComponents.hour &&
                    startTimeComponents.minute! < minTimeComponents.minute) {
                    return false
                }

            case .specificDate:
                // Student must be scheduled on this specific date
                if let requiredDate = parseConstraintDate(constraint.constraintValue) {
                    let calendar = Calendar.current
                    if !calendar.isDate(date, inSameDayAs: requiredDate) {
                        return false
                    }
                }

            case .excludeDate:
                // Student cannot be scheduled on this date
                if let excludedDate = parseConstraintDate(constraint.constraintValue) {
                    let calendar = Calendar.current
                    if calendar.isDate(date, inSameDayAs: excludedDate) {
                        return false
                    }
                }

            case .weekPreference:
                // Handled during cohort assignment
                break
            }
        }

        return true
    }

    private func createUnscheduledSlot(
        studentId: UUID,
        sectionId: UUID,
        examSession: ExamSession,
        courseId: UUID
    ) async throws {
        let slot = ExamSlot(
            id: UUID(),
            courseId: courseId,
            studentId: studentId,
            sectionId: sectionId,
            examSessionId: examSession.id,
            date: Date(), // Placeholder date
            startTime: Date(),
            endTime: Date(),
            isScheduled: false,
            isLocked: false,
            notes: "Could not schedule due to constraints or time limitations"
        )

        try await scheduleRepository.updateExamSlot(slot)
    }

    // MARK: - Helper Methods

    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int) {
        let components = timeString.split(separator: ":").map { Int($0) ?? 0 }
        return (hour: components[0], minute: components.count > 1 ? components[1] : 0)
    }

    private func parseConstraintTime(_ timeString: String) -> String {
        // Constraint value is already in HH:MM format
        return timeString
    }

    private func parseConstraintDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    private func combineDateTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute
        combined.second = timeComponents.second

        return calendar.date(from: combined) ?? date
    }
}
