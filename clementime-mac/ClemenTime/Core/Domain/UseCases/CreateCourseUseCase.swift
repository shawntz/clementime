//
//  CreateCourseUseCase.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct CreateCourseInput {
    let name: String
    let term: String
    let quarterStartDate: Date
    let examDay: DayOfWeek
    let totalExams: Int
    let cohorts: [CohortInput]
    let examSessions: [ExamSessionInput]
    let settings: CourseSettings
    let createdBy: UUID
}

struct CohortInput {
    let name: String
    let weekType: WeekType
    let colorHex: String
    let sortOrder: Int
}

struct ExamSessionInput {
    let examNumber: Int
    let oddWeekDate: Date
    let evenWeekDate: Date
    let theme: String?
    let startTime: String  // "HH:MM"
    let endTime: String    // "HH:MM"
    let durationMinutes: Int
    let bufferMinutes: Int
}

struct CreateCourseOutput {
    let course: Course
    let cohorts: [Cohort]
    let examSessions: [ExamSession]
}

class CreateCourseUseCase {
    private let courseRepository: CourseRepository
    private let cohortRepository: CohortRepository
    private let examSessionRepository: ExamSessionRepository

    init(
        courseRepository: CourseRepository,
        cohortRepository: CohortRepository,
        examSessionRepository: ExamSessionRepository
    ) {
        self.courseRepository = courseRepository
        self.cohortRepository = cohortRepository
        self.examSessionRepository = examSessionRepository
    }

    func execute(input: CreateCourseInput) async throws -> CreateCourseOutput {
        // 1. Validate input
        guard !input.name.isEmpty else {
            throw UseCaseError.invalidInput
        }

        guard !input.cohorts.isEmpty else {
            throw UseCaseError.invalidInput
        }

        guard input.examSessions.count == input.totalExams else {
            throw UseCaseError.invalidInput
        }

        // 2. Create course
        let courseId = UUID()
        let course = Course(
            id: courseId,
            name: input.name,
            term: input.term,
            quarterStartDate: input.quarterStartDate,
            examDay: input.examDay,
            totalExams: input.totalExams,
            isActive: true,
            createdBy: input.createdBy,
            settings: input.settings
        )

        let createdCourse = try await courseRepository.createCourse(course)

        // 3. Create cohorts
        var createdCohorts: [Cohort] = []
        for cohortInput in input.cohorts {
            let cohort = Cohort(
                id: UUID(),
                courseId: courseId,
                name: cohortInput.name,
                weekType: cohortInput.weekType,
                colorHex: cohortInput.colorHex,
                sortOrder: cohortInput.sortOrder
            )
            let created = try await cohortRepository.createCohort(cohort)
            createdCohorts.append(created)
        }

        // 4. Create exam sessions
        var createdExamSessions: [ExamSession] = []
        for sessionInput in input.examSessions {
            let examSession = ExamSession(
                id: UUID(),
                courseId: courseId,
                examNumber: sessionInput.examNumber,
                oddWeekDate: sessionInput.oddWeekDate,
                evenWeekDate: sessionInput.evenWeekDate,
                theme: sessionInput.theme,
                startTime: sessionInput.startTime,
                endTime: sessionInput.endTime,
                durationMinutes: sessionInput.durationMinutes,
                bufferMinutes: sessionInput.bufferMinutes
            )
            let created = try await examSessionRepository.createExamSession(examSession)
            createdExamSessions.append(created)
        }

        return CreateCourseOutput(
            course: createdCourse,
            cohorts: createdCohorts,
            examSessions: createdExamSessions
        )
    }
}
