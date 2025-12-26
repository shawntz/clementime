//
//  GenerateScheduleUseCase.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
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
        // Load all data needed for scheduling
        guard let course = try await courseRepository.fetchCourse(id: input.courseId) else {
            throw UseCaseError.courseNotFound
        }
        var cohorts = try await cohortRepository.fetchCohorts(courseId: input.courseId)
        let students = try await studentRepository.fetchStudents(courseId: input.courseId)
        let sections = try await sectionRepository.fetchSections(courseId: input.courseId)
        let examSessions = try await examSessionRepository.fetchExamSessions(courseId: input.courseId)

        // Load all constraints grouped by student ID
        var constraintsByStudent: [UUID: [Constraint]] = [:]
        for student in students {
            let studentConstraints = try await constraintRepository.fetchConstraints(studentId: student.id)
            constraintsByStudent[student.id] = studentConstraints
        }

        // Ensure "All Students" cohort exists with isDefault = true
        let allStudentsCohort: Cohort
        if let existingDefault = cohorts.first(where: { $0.isDefault }) {
            allStudentsCohort = existingDefault
        } else if let existingByName = cohorts.first(where: { $0.name == "All Students" }) {
            // Found "All Students" cohort but isDefault is not set - fix it
            var updatedCohort = existingByName
            updatedCohort.isDefault = true
            try await cohortRepository.updateCohort(updatedCohort)
            allStudentsCohort = updatedCohort

            // Update local cohorts array
            cohorts = try await cohortRepository.fetchCohorts(courseId: input.courseId)
        } else {
            // Create "All Students" cohort
            let newAllStudentsCohort = Cohort.createAllStudentsCohort(courseId: input.courseId)
            allStudentsCohort = try await cohortRepository.createCohort(newAllStudentsCohort)

            // Update local cohorts array
            cohorts = try await cohortRepository.fetchCohorts(courseId: input.courseId)
        }

        // Filter exam sessions if starting from a specific exam
        let sessionsToGenerate: [ExamSession]
        if let startingExam = input.startingFromExam {
            sessionsToGenerate = examSessions.filter { $0.examNumber >= startingExam }
        } else {
            sessionsToGenerate = examSessions
        }

        var totalScheduled = 0
        var totalUnscheduled = 0
        var allErrors: [String] = []
        var allUnscheduledStudents: [UUID] = []

        // Generate slots for each exam session
        for examSession in sessionsToGenerate {
            // Delete existing unlocked slots for this exam session before regenerating
            try await scheduleRepository.deleteUnlockedExamSlots(examSessionId: examSession.id)

            let result = try await generateSlotsForExamSession(
                examSession: examSession,
                course: course,
                students: students,
                sections: sections,
                cohorts: cohorts,
                allStudentsCohort: allStudentsCohort,
                constraints: constraintsByStudent
            )

            totalScheduled += result.scheduled
            totalUnscheduled += result.unscheduled
            allErrors.append(contentsOf: result.errors)
            allUnscheduledStudents.append(contentsOf: result.unscheduledStudents)
        }

        return ScheduleResult(
            scheduledCount: totalScheduled,
            unscheduledCount: totalUnscheduled,
            errors: allErrors,
            unscheduledStudents: allUnscheduledStudents
        )
    }

    // MARK: - Private Methods

    private func generateSlotsForExamSession(
        examSession: ExamSession,
        course: Course,
        students: [Student],
        sections: [Section],
        cohorts: [Cohort],
        allStudentsCohort: Cohort,
        constraints: [UUID: [Constraint]]
    ) async throws -> (scheduled: Int, unscheduled: Int, errors: [String], unscheduledStudents: [UUID]) {
        var scheduled = 0
        var unscheduled = 0
        var errors: [String] = []
        var unscheduledStudents: [UUID] = []

        // Determine which students are eligible for this exam session
        let eligibleStudents: [Student]
        if let assignedCohortId = examSession.assignedCohortId {
            // Specific cohort exam - only students in that cohort
            eligibleStudents = students.filter { $0.cohortId == assignedCohortId }
        } else {
            // "All Students" exam - all students
            eligibleStudents = students
        }

        // Generate slots for each section
        for section in sections where section.isActive {
            // Calculate exam date: weekStartDate + section.weekday offset
            let examDate = calculateExamDate(
                weekStartDate: examSession.weekStartDate,
                weekday: section.weekday
            )

            // Filter students by section
            let sectionStudents = eligibleStudents.filter { $0.sectionId == section.id && $0.isActive }

            if sectionStudents.isEmpty {
                continue
            }

            // Generate slots for this section
            let result = try await generateSlotsForSection(
                students: sectionStudents,
                section: section,
                examSession: examSession,
                examDate: examDate,
                course: course,
                constraints: constraints
            )

            scheduled += result.scheduled
            unscheduled += result.unscheduled
            errors.append(contentsOf: result.errors)
            unscheduledStudents.append(contentsOf: result.unscheduledStudents)
        }

        return (scheduled, unscheduled, errors, unscheduledStudents)
    }

    private func generateSlotsForSection(
        students: [Student],
        section: Section,
        examSession: ExamSession,
        examDate: Date,
        course: Course,
        constraints: [UUID: [Constraint]]
    ) async throws -> (scheduled: Int, unscheduled: Int, errors: [String], unscheduledStudents: [UUID]) {
        var scheduled = 0
        var unscheduled = 0
        var errors: [String] = []
        var unscheduledStudents: [UUID] = []

        // Prioritize students by constraint type
        let orderedStudents = prioritizeStudents(students, constraints: constraints, seed: examSession.examNumber)

        // Parse section start and end times
        let calendar = Calendar.current
        let startTimeComponents = parseTime(section.startTime)
        let endTimeComponents = parseTime(section.endTime)

        print("📅 [Schedule] Section: \(section.code)")
        print("📅 [Schedule] Exam date: \(examDate)")
        print("📅 [Schedule] Section start time string: \(section.startTime)")
        print("📅 [Schedule] Section end time string: \(section.endTime)")
        print("📅 [Schedule] Parsed start: \(startTimeComponents.hour):\(startTimeComponents.minute)")
        print("📅 [Schedule] Parsed end: \(endTimeComponents.hour):\(endTimeComponents.minute)")

        // Create base time on exam date
        guard var currentTime = calendar.date(
            bySettingHour: startTimeComponents.hour,
            minute: startTimeComponents.minute,
            second: 0,
            of: examDate
        ),
        let sectionEndTime = calendar.date(
            bySettingHour: endTimeComponents.hour,
            minute: endTimeComponents.minute,
            second: 0,
            of: examDate
        ) else {
            errors.append("Failed to parse section times for section \(section.code)")
            return (0, 0, errors, [])
        }

        print("📅 [Schedule] Current time (section start): \(currentTime)")
        print("📅 [Schedule] Section end time: \(sectionEndTime)")
        print("📅 [Schedule] Exam duration: \(examSession.durationMinutes) min, Buffer: \(examSession.bufferMinutes) min")

        // Validate section time range
        let sectionDurationMinutes = sectionEndTime.timeIntervalSince(currentTime) / 60
        print("📅 [Schedule] Section duration: \(sectionDurationMinutes) minutes")

        if sectionDurationMinutes <= 0 {
            let errorMsg = "Section \(section.code) has invalid time range: start \(section.startTime) >= end \(section.endTime)"
            print("❌ [Schedule] \(errorMsg)")
            errors.append(errorMsg)
            return (0, 0, errors, [])
        }

        if sectionDurationMinutes < Double(examSession.durationMinutes) {
            let errorMsg = "Section \(section.code) duration (\(sectionDurationMinutes) min) is less than exam duration (\(examSession.durationMinutes) min)"
            print("❌ [Schedule] \(errorMsg)")
            errors.append(errorMsg)
            return (0, 0, errors, [])
        }

        // Load existing slots to check for locked slots
        let existingSlots = try await scheduleRepository.fetchExamSlots(
            courseId: course.id,
            examNumber: examSession.examNumber
        )

        // Allocate time slots for each student
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

            print("📅 [Schedule] Student: \(student.fullName) - Current: \(currentTime), End: \(slotEndTime), Section End: \(sectionEndTime)")

            // Check if we have time remaining in the section
            if slotEndTime > sectionEndTime {
                print("⚠️ [Schedule] Insufficient time for \(student.fullName): slotEnd \(slotEndTime) > sectionEnd \(sectionEndTime)")
                // Create unscheduled slot
                try await createUnscheduledSlot(
                    studentId: student.id,
                    sectionId: section.id,
                    examSession: examSession,
                    courseId: course.id,
                    reason: "Insufficient time remaining in section"
                )
                unscheduled += 1
                unscheduledStudents.append(student.id)
                continue
            }

            // Check constraints
            if !canScheduleStudent(
                student: student,
                constraints: constraints[student.id] ?? [],
                date: examDate,
                startTime: currentTime,
                endTime: slotEndTime
            ) {
                // Create unscheduled slot
                try await createUnscheduledSlot(
                    studentId: student.id,
                    sectionId: section.id,
                    examSession: examSession,
                    courseId: course.id,
                    reason: "Constraint violation"
                )
                unscheduled += 1
                unscheduledStudents.append(student.id)
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
                startTime: currentTime,
                endTime: slotEndTime,
                isScheduled: true,
                isLocked: false,
                notes: nil
            )

            try await scheduleRepository.updateExamSlot(slot)
            scheduled += 1

            // Advance time for next student (duration + buffer)
            currentTime = slotEndTime.addingTimeInterval(
                TimeInterval(examSession.bufferMinutes * 60)
            )
        }

        return (scheduled, unscheduled, errors, unscheduledStudents)
    }

    private func calculateExamDate(weekStartDate: Date, weekday: Int) -> Date {
        let calendar = Calendar.current

        // weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Get the weekday of the week start date
        let weekStartWeekday = calendar.component(.weekday, from: weekStartDate)

        // Calculate days to add
        var daysToAdd = weekday - weekStartWeekday
        if daysToAdd < 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: weekStartDate) ?? weekStartDate
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

            let hasTimeBefore = studentConstraints.contains { $0.type == .timeBefore && $0.isActive }
            let hasTimeAfter = studentConstraints.contains { $0.type == .timeAfter && $0.isActive }
            let hasOther = studentConstraints.contains {
                ($0.type == .specificDate || $0.type == .excludeDate) && $0.isActive
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

        // Shuffle within each group for fairness (using seed for determinism)
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        return timeBefore.shuffled(using: &rng) +
               timeAfter.shuffled(using: &rng) +
               otherConstraints.shuffled(using: &rng) +
               noConstraints.shuffled(using: &rng)
    }

    private func canScheduleStudent(
        student: Student,
        constraints: [Constraint],
        date: Date,
        startTime: Date,
        endTime: Date
    ) -> Bool {
        let calendar = Calendar.current

        for constraint in constraints where constraint.isActive {
            switch constraint.type {
            case .timeBefore:
                // Student must start BEFORE this time
                let maxTimeComponents = parseTime(constraint.value)
                let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)

                if let startHour = startTimeComponents.hour,
                   let startMinute = startTimeComponents.minute {
                    if startHour > maxTimeComponents.hour ||
                       (startHour == maxTimeComponents.hour && startMinute >= maxTimeComponents.minute) {
                        return false
                    }
                }

            case .timeAfter:
                // Student must start AFTER this time
                let minTimeComponents = parseTime(constraint.value)
                let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)

                if let startHour = startTimeComponents.hour,
                   let startMinute = startTimeComponents.minute {
                    if startHour < minTimeComponents.hour ||
                       (startHour == minTimeComponents.hour && startMinute < minTimeComponents.minute) {
                        return false
                    }
                }

            case .specificDate:
                // Student must be scheduled on this specific date
                if let requiredDate = parseConstraintDate(constraint.value) {
                    if !calendar.isDate(date, inSameDayAs: requiredDate) {
                        return false
                    }
                }

            case .excludeDate:
                // Student cannot be scheduled on this date
                if let excludedDate = parseConstraintDate(constraint.value) {
                    if calendar.isDate(date, inSameDayAs: excludedDate) {
                        return false
                    }
                }

            case .weekPreference:
                // Week preference is handled via cohort assignment, not during scheduling
                break
            }
        }

        return true
    }

    private func createUnscheduledSlot(
        studentId: UUID,
        sectionId: UUID,
        examSession: ExamSession,
        courseId: UUID,
        reason: String
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
            notes: reason
        )

        try await scheduleRepository.updateExamSlot(slot)
    }

    // MARK: - Helper Methods

    private func parseTime(_ timeString: String) -> (hour: Int, minute: Int) {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        return (hour: components.first ?? 0, minute: components.count > 1 ? components[1] : 0)
    }

    private func parseConstraintDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
