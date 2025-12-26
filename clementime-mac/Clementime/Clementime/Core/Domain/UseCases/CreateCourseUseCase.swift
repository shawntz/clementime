//
//  CreateCourseUseCase.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct CreateCourseInput {
    let name: String
    let term: String
    let quarterStartDate: Date
    let quarterEndDate: Date
    let totalExams: Int
    let cohorts: [CohortInput]
    let examSessions: [ExamSessionInput]
    let settings: CourseSettings
    let createdBy: UUID
}

struct CohortInput {
    let name: String
    let colorHex: String
    let sortOrder: Int
    let isDefault: Bool
}

struct ExamSessionInput {
    let examNumber: Int
    let weekStartDate: Date
    let assignedCohortId: UUID?
    let theme: String?
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
            quarterEndDate: input.quarterEndDate,
            totalExams: input.totalExams,
            isActive: true,
            createdBy: input.createdBy,
            settings: input.settings
        )

        let createdCourse = try await courseRepository.createCourse(course)

        // 3. Create cohorts
        var createdCohorts: [Cohort] = []

        // Always create an "All Students" default cohort first
        let allStudentsCohort = Cohort.createAllStudentsCohort(courseId: courseId)
        let createdAllStudents = try await cohortRepository.createCohort(allStudentsCohort)
        createdCohorts.append(createdAllStudents)

        // Then create user-defined cohorts
        for cohortInput in input.cohorts {
            let cohort = Cohort(
                id: UUID(),
                courseId: courseId,
                name: cohortInput.name,
                colorHex: cohortInput.colorHex,
                sortOrder: cohortInput.sortOrder,
                isDefault: cohortInput.isDefault
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
                weekStartDate: sessionInput.weekStartDate,
                assignedCohortId: sessionInput.assignedCohortId,
                theme: sessionInput.theme,
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
