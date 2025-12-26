//
//  ExportCourseUseCase.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation

class ExportCourseUseCase {
    private let courseRepository: CourseRepository
    private let cohortRepository: CohortRepository
    private let sectionRepository: SectionRepository
    private let studentRepository: StudentRepository
    private let examSessionRepository: ExamSessionRepository
    private let scheduleRepository: ScheduleRepository
    private let constraintRepository: ConstraintRepository
    private let taUserRepository: TAUserRepository

    init(
        courseRepository: CourseRepository,
        cohortRepository: CohortRepository,
        sectionRepository: SectionRepository,
        studentRepository: StudentRepository,
        examSessionRepository: ExamSessionRepository,
        scheduleRepository: ScheduleRepository,
        constraintRepository: ConstraintRepository,
        taUserRepository: TAUserRepository
    ) {
        self.courseRepository = courseRepository
        self.cohortRepository = cohortRepository
        self.sectionRepository = sectionRepository
        self.studentRepository = studentRepository
        self.examSessionRepository = examSessionRepository
        self.scheduleRepository = scheduleRepository
        self.constraintRepository = constraintRepository
        self.taUserRepository = taUserRepository
    }

    func execute(courseId: UUID) async throws -> URL {
        // Load all course data
        guard let course = try await courseRepository.fetchCourse(id: courseId) else {
            throw UseCaseError.courseNotFound
        }

        let cohorts = try await cohortRepository.fetchCohorts(courseId: courseId)
        let sections = try await sectionRepository.fetchSections(courseId: courseId)
        let students = try await studentRepository.fetchStudents(courseId: courseId)
        let examSessions = try await examSessionRepository.fetchExamSessions(courseId: courseId)
        let taUsers = try await taUserRepository.fetchTAUsers(courseId: courseId)

        // Load exam slots for all exam sessions
        var allExamSlots: [ExamSlot] = []
        for session in examSessions {
            let slots = try await scheduleRepository.fetchExamSlots(courseId: courseId, examNumber: session.examNumber)
            allExamSlots.append(contentsOf: slots)
        }

        // Load constraints for all students
        var allConstraints: [Constraint] = []
        for student in students {
            let constraints = try await constraintRepository.fetchConstraints(studentId: student.id)
            allConstraints.append(contentsOf: constraints)
        }

        // Convert domain models to export data models
        let courseExport = CourseExport(
            version: CourseExport.currentVersion,
            exportedAt: Date(),
            course: CourseExportData(
                name: course.name,
                term: course.term,
                quarterStartDate: course.quarterStartDate,
                quarterEndDate: course.quarterEndDate,
                totalExams: course.totalExams,
                isActive: course.isActive,
                settingsJSON: course.settings.encode(),
                metadataJSON: encodeMetadata(course.metadata)
            ),
            cohorts: cohorts.map { cohort in
                CohortExportData(
                    id: cohort.id,
                    name: cohort.name,
                    colorHex: cohort.colorHex,
                    sortOrder: cohort.sortOrder,
                    isDefault: cohort.isDefault
                )
            },
            sections: sections.map { section in
                SectionExportData(
                    id: section.id,
                    code: section.code,
                    name: section.name,
                    location: section.location,
                    assignedTAId: section.assignedTAId,
                    weekday: section.weekday,
                    startTime: section.startTime,
                    endTime: section.endTime,
                    isActive: section.isActive
                )
            },
            students: students.map { student in
                StudentExportData(
                    id: student.id,
                    sectionId: student.sectionId,
                    cohortId: student.cohortId,
                    sisUserId: student.sisUserId,
                    email: student.email,
                    fullName: student.fullName,
                    slackUserId: student.slackUserId,
                    slackUsername: student.slackUsername,
                    isActive: student.isActive
                )
            },
            examSessions: examSessions.map { session in
                ExamSessionExportData(
                    id: session.id,
                    examNumber: session.examNumber,
                    weekStartDate: session.weekStartDate,
                    assignedCohortId: session.assignedCohortId,
                    theme: session.theme,
                    durationMinutes: session.durationMinutes,
                    bufferMinutes: session.bufferMinutes
                )
            },
            examSlots: allExamSlots.map { slot in
                ExamSlotExportData(
                    id: slot.id,
                    studentId: slot.studentId,
                    sectionId: slot.sectionId,
                    examSessionId: slot.examSessionId,
                    date: slot.date,
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                    isScheduled: slot.isScheduled,
                    isLocked: slot.isLocked,
                    notes: slot.notes
                )
            },
            constraints: allConstraints.map { constraint in
                ConstraintExportData(
                    id: constraint.id,
                    studentId: constraint.studentId,
                    type: constraint.type.rawValue,
                    value: constraint.value,
                    description: constraint.constraintDescription,
                    isActive: constraint.isActive
                )
            },
            taUsers: taUsers.map { taUser in
                TAUserExportData(
                    id: taUser.id,
                    firstName: taUser.firstName,
                    lastName: taUser.lastName,
                    email: taUser.email,
                    username: taUser.username,
                    role: taUser.role.rawValue,
                    permissionsJSON: encodePermissions(taUser.customPermissions),
                    location: taUser.location,
                    slackId: taUser.slackId,
                    isActive: taUser.isActive
                )
            }
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(courseExport)

        // Write to temporary file
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "\(course.name.replacingOccurrences(of: " ", with: "_"))_\(course.term.replacingOccurrences(of: " ", with: "_")).clementime"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        try jsonData.write(to: fileURL)

        return fileURL
    }

    // MARK: - Helper Methods

    private func encodeMetadata(_ metadata: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(metadata),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func encodePermissions(_ permissions: [Permission]) -> String {
        let permissionTypes = permissions.map { $0.type.rawValue }
        guard let data = try? JSONEncoder().encode(permissionTypes),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}
