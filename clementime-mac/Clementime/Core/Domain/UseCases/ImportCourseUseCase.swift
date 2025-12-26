//
//  ImportCourseUseCase.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation

class ImportCourseUseCase {
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

    func execute(fileURL: URL, currentUserId: UUID) async throws -> CourseImportResult {
        var result = CourseImportResult(
            success: false,
            importedCourseId: nil,
            errors: [],
            warnings: []
        )

        // Read and decode file
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let courseExport: CourseExport
        do {
            courseExport = try decoder.decode(CourseExport.self, from: jsonData)
        } catch {
            result.errors.append("Failed to decode course file: \(error.localizedDescription)")
            return result
        }

        // Verify version compatibility
        if courseExport.version != CourseExport.currentVersion {
            result.warnings.append("File version \(courseExport.version) may not be fully compatible with current version \(CourseExport.currentVersion)")
        }

        // Generate new course ID
        let newCourseId = UUID()

        // Create ID mappings for imported entities
        var cohortIdMap: [UUID: UUID] = [:]
        var sectionIdMap: [UUID: UUID] = [:]
        var studentIdMap: [UUID: UUID] = [:]
        var examSessionIdMap: [UUID: UUID] = [:]
        var taUserIdMap: [UUID: UUID] = [:]

        do {
            // 1. Import course
            let importedCourse = Course(
                id: newCourseId,
                name: "\(courseExport.course.name) (Imported)",
                term: courseExport.course.term,
                quarterStartDate: courseExport.course.quarterStartDate,
                quarterEndDate: courseExport.course.quarterEndDate,
                totalExams: courseExport.course.totalExams,
                isActive: courseExport.course.isActive,
                createdBy: currentUserId,
                settings: CourseSettings.decode(from: courseExport.course.settingsJSON),
                metadata: decodeMetadata(courseExport.course.metadataJSON ?? "{}")
            )
            _ = try await courseRepository.createCourse(importedCourse)

            // 2. Import cohorts
            for cohortData in courseExport.cohorts {
                let newCohortId = UUID()
                cohortIdMap[cohortData.id] = newCohortId

                let cohort = Cohort(
                    id: newCohortId,
                    courseId: newCourseId,
                    name: cohortData.name,
                    colorHex: cohortData.colorHex,
                    sortOrder: cohortData.sortOrder,
                    isDefault: cohortData.isDefault
                )
                _ = try await cohortRepository.createCohort(cohort)
                result.cohortsImported += 1
            }

            // 3. Import sections (with new cohort IDs if referenced)
            for sectionData in courseExport.sections {
                let newSectionId = UUID()
                sectionIdMap[sectionData.id] = newSectionId

                let section = Section(
                    id: newSectionId,
                    courseId: newCourseId,
                    code: sectionData.code,
                    name: sectionData.name,
                    location: sectionData.location,
                    assignedTAId: nil, // Don't copy TA assignments
                    weekday: sectionData.weekday,
                    startTime: sectionData.startTime,
                    endTime: sectionData.endTime,
                    isActive: sectionData.isActive
                )
                _ = try await sectionRepository.createSection(section)
                result.sectionsImported += 1
            }

            // 4. Import students
            for studentData in courseExport.students {
                let newStudentId = UUID()
                studentIdMap[studentData.id] = newStudentId

                guard let newSectionId = sectionIdMap[studentData.sectionId],
                      let newCohortId = cohortIdMap[studentData.cohortId] else {
                    result.warnings.append("Skipped student \(studentData.fullName): referenced section or cohort not found")
                    continue
                }

                let student = Student(
                    id: newStudentId,
                    courseId: newCourseId,
                    sectionId: newSectionId,
                    sisUserId: studentData.sisUserId,
                    email: studentData.email,
                    fullName: studentData.fullName,
                    cohortId: newCohortId,
                    slackUserId: studentData.slackUserId,
                    slackUsername: studentData.slackUsername,
                    isActive: studentData.isActive
                )
                _ = try await studentRepository.createStudent(student)
                result.studentsImported += 1
            }

            // 5. Import exam sessions
            for sessionData in courseExport.examSessions {
                let newSessionId = UUID()
                examSessionIdMap[sessionData.id] = newSessionId

                let mappedCohortId = sessionData.assignedCohortId.flatMap { cohortIdMap[$0] }

                let examSession = ExamSession(
                    id: newSessionId,
                    courseId: newCourseId,
                    examNumber: sessionData.examNumber,
                    weekStartDate: sessionData.weekStartDate,
                    assignedCohortId: mappedCohortId,
                    theme: sessionData.theme,
                    durationMinutes: sessionData.durationMinutes,
                    bufferMinutes: sessionData.bufferMinutes
                )
                _ = try await examSessionRepository.createExamSession(examSession)
                result.examSessionsImported += 1
            }

            // 6. Import exam slots
            for slotData in courseExport.examSlots {
                guard let newStudentId = studentIdMap[slotData.studentId],
                      let newSectionId = sectionIdMap[slotData.sectionId],
                      let newExamSessionId = examSessionIdMap[slotData.examSessionId] else {
                    result.warnings.append("Skipped exam slot: referenced entity not found")
                    continue
                }

                let examSlot = ExamSlot(
                    id: UUID(),
                    courseId: newCourseId,
                    studentId: newStudentId,
                    sectionId: newSectionId,
                    examSessionId: newExamSessionId,
                    date: slotData.date,
                    startTime: slotData.startTime,
                    endTime: slotData.endTime,
                    isScheduled: slotData.isScheduled,
                    isLocked: slotData.isLocked,
                    notes: slotData.notes
                )
                try await scheduleRepository.updateExamSlot(examSlot)
                result.examSlotsImported += 1
            }

            // 7. Import constraints
            for constraintData in courseExport.constraints {
                guard let newStudentId = studentIdMap[constraintData.studentId] else {
                    result.warnings.append("Skipped constraint: student not found")
                    continue
                }

                guard let constraintType = ConstraintType(rawValue: constraintData.type) else {
                    result.warnings.append("Skipped constraint: unknown type '\(constraintData.type)'")
                    continue
                }

                let constraint = Constraint(
                    id: UUID(),
                    studentId: newStudentId,
                    type: constraintType,
                    value: constraintData.value,
                    constraintDescription: constraintData.description,
                    isActive: constraintData.isActive
                )
                _ = try await constraintRepository.createConstraint(constraint)
                result.constraintsImported += 1
            }

            // 8. Import TA users (create new TAs for this course)
            for taUserData in courseExport.taUsers {
                let newTAUserId = UUID()
                taUserIdMap[taUserData.id] = newTAUserId

                guard let role = UserRole(rawValue: taUserData.role) else {
                    result.warnings.append("Skipped TA user \(taUserData.email): unknown role '\(taUserData.role)'")
                    continue
                }

                let taUser = TAUser(
                    id: newTAUserId,
                    courseId: newCourseId,
                    firstName: taUserData.firstName,
                    lastName: taUserData.lastName,
                    email: taUserData.email,
                    username: taUserData.username,
                    role: role,
                    customPermissions: decodePermissions(taUserData.permissionsJSON),
                    location: taUserData.location,
                    slackId: taUserData.slackId,
                    isActive: taUserData.isActive
                )
                _ = try await taUserRepository.createTAUser(taUser)
                result.taUsersImported += 1
            }

            result.success = true
            result.importedCourseId = newCourseId

        } catch {
            result.errors.append("Import failed: \(error.localizedDescription)")
            result.success = false
        }

        return result
    }

    // MARK: - Helper Methods

    private func decodeMetadata(_ json: String) -> [String: String] {
        guard let data = json.data(using: .utf8),
              let metadata = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return metadata
    }

    private func decodePermissions(_ json: String) -> [Permission] {
        guard let data = json.data(using: .utf8),
              let permissionStrings = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return permissionStrings.compactMap { string in
            guard let type = PermissionType(rawValue: string) else { return nil }
            return Permission(type: type, isGranted: true)
        }
    }
}
