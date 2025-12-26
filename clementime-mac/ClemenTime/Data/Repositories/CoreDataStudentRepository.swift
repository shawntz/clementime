//
//  CoreDataStudentRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
@preconcurrency import CoreData

class CoreDataStudentRepository: StudentRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchStudents(courseId: UUID) async throws -> [Student] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "fullName", ascending: true)]

        return try await context.perform(schedule: .immediate) {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchStudents(sectionId: UUID) async throws -> [Student] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "sectionId == %@", sectionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "fullName", ascending: true)]

        return try await context.perform(schedule: .immediate) {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchStudent(id: UUID) async throws -> Student? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform(schedule: .immediate) {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func fetchStudent(sisUserId: String, courseId: UUID) async throws -> Student? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "sisUserId == %@ AND courseId == %@", sisUserId, courseId as CVarArg)
        request.fetchLimit = 1

        return try await context.perform(schedule: .immediate) {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createStudent(_ student: Student) async throws -> Student {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform(schedule: .enqueued) {
            let entity = StudentEntity.create(from: student, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateStudent(_ student: Student) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform(schedule: .enqueued) {
            let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
            request.predicate = NSPredicate(format: "id == %@", student.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: student)
            try context.save()
        }
    }

    func deleteStudent(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform(schedule: .enqueued) {
            let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }

    func deleteAllStudents(courseId: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform(schedule: .enqueued) {
            let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
            request.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)

            let students = try context.fetch(request)

            for student in students {
                context.delete(student)
            }

            try context.save()
        }
    }

    func importStudents(from csvURL: URL, courseId: UUID, randomlyAssignCohorts: Bool = false) async throws -> ImportResult {
        let context = persistentContainer.newBackgroundContext()

        // Ensure the context sees the latest data from the persistent store
        context.stalenessInterval = 0 // Don't use cached data
        context.automaticallyMergesChangesFromParent = true
        context.refreshAllObjects()

        // Access the security-scoped resource
        guard csvURL.startAccessingSecurityScopedResource() else {
            throw RepositoryError.csvValidationError("Unable to access file. Please try again.")
        }
        defer {
            csvURL.stopAccessingSecurityScopedResource()
        }

        return try await context.perform(schedule: .enqueued) {
            // Fetch all cohorts if random assignment is enabled
            var availableCohorts: [CohortEntity] = []
            var cohortIndex = 0

            if randomlyAssignCohorts {
                let cohortRequest = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
                cohortRequest.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
                cohortRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
                let allCohortsForImport = try context.fetch(cohortRequest)

                // Filter to only custom cohorts (exclude "All Students" by flag AND name)
                availableCohorts = allCohortsForImport.filter { cohort in
                    let isDefault = cohort.value(forKey: "isDefault") as? Bool ?? false
                    let name = cohort.name ?? ""
                    return !isDefault && name != "All Students"
                }

                // Shuffle for random distribution
                availableCohorts.shuffle()

                guard !availableCohorts.isEmpty else {
                    throw RepositoryError.csvValidationError("Random cohort assignment requires at least one custom cohort (not 'All Students') to be created first")
                }
            }

            // Read CSV file
            let csvData = try String(contentsOf: csvURL, encoding: .utf8)
            let lines = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count > 1 else {
                throw RepositoryError.csvValidationError("CSV file is empty or contains no data rows")
            }

            // Parse header
            let header = CSVParser.parseCSVLine(lines[0])

            // Validate required columns with helpful error messages
            let requiredColumns = [
                ("sis_user_id", ["sis", "id", "sis_user_id", "student_id"]),
                ("full_name", ["name", "full_name", "fullname", "student_name"]),
                ("email", ["email", "email_address", "student_email"]),
                ("section_code", ["section", "section_code", "section_id"])
            ]

            var columnIndices: [String: Int] = [:]
            var missingColumns: [String] = []

            for (columnName, aliases) in requiredColumns {
                if let index = header.firstIndex(where: { headerCol in
                    aliases.contains { headerCol.lowercased().contains($0) }
                }) {
                    columnIndices[columnName] = index
                } else {
                    missingColumns.append(columnName)
                }
            }

            guard missingColumns.isEmpty else {
                let errorMessage = """
                CSV file is missing required columns: \(missingColumns.joined(separator: ", "))

                Required columns:
                • sis_user_id (or: id, student_id)
                • full_name (or: name, student_name)
                • email (or: email_address)
                • section_code (or: section, section_id)

                Found columns: \(header.joined(separator: ", "))
                """
                throw RepositoryError.csvValidationError(errorMessage)
            }

            // Extract indices
            guard let sisIdIndex = columnIndices["sis_user_id"],
                  let nameIndex = columnIndices["full_name"],
                  let emailIndex = columnIndices["email"],
                  let sectionIndex = columnIndices["section_code"] else {
                throw RepositoryError.csvValidationError("Failed to map column indices")
            }

            var successCount = 0
            var failureCount = 0
            var errors: [ImportResult.ImportError] = []

            // Process each row
            for (index, line) in lines.enumerated() where index > 0 {
                let fields = CSVParser.parseCSVLine(line)

                guard fields.count > max(sisIdIndex, nameIndex, emailIndex, sectionIndex) else {
                    errors.append(ImportResult.ImportError(
                        row: index + 1,
                        studentName: nil,
                        reason: "Invalid field count"
                    ))
                    failureCount += 1
                    continue
                }

                let sisUserId = fields[sisIdIndex]
                let fullName = fields[nameIndex]
                let email = fields[emailIndex]
                let sectionField = fields[sectionIndex].trimmingCharacters(in: .whitespacesAndNewlines)

                // Parse section codes (handle comma-separated format like "F25-STATS-60-01, F25-STATS-60-010")
                // Strategy: Use the SECOND element if exactly 2 elements, flag if more than 2
                let sectionCodes = sectionField
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // Determine which section code to use
                let actualSectionCode: String
                let needsManualReview: Bool

                if sectionCodes.count == 1 {
                    // Single section code - use it
                    actualSectionCode = sectionCodes[0]
                    needsManualReview = false
                } else if sectionCodes.count == 2 {
                    // Two section codes - use the second one (actual enrolled discussion section)
                    actualSectionCode = sectionCodes[1]
                    needsManualReview = false
                } else if sectionCodes.count > 2 {
                    // More than 2 section codes - flag for manual intervention
                    actualSectionCode = sectionCodes.last ?? ""
                    needsManualReview = true
                } else {
                    // No section codes (empty field)
                    actualSectionCode = ""
                    needsManualReview = true
                }

                // Find or create student
                let studentRequest = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
                studentRequest.predicate = NSPredicate(format: "sisUserId == %@ AND courseId == %@", sisUserId, courseId as CVarArg)
                studentRequest.fetchLimit = 1

                // Try to match the actual section code
                var matchedSection: SectionEntity? = nil
                let unmatchedSectionCode: String?

                if !actualSectionCode.isEmpty {
                    // Find matchable section (excluding sections marked to ignore, case-insensitive)
                    let sectionRequest = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
                    sectionRequest.predicate = NSPredicate(
                        format: "code ==[c] %@ AND courseId == %@ AND shouldIgnoreForMatching == NO",
                        actualSectionCode, courseId as CVarArg
                    )
                    sectionRequest.fetchLimit = 1

                    matchedSection = try context.fetch(sectionRequest).first
                }

                // Determine section and cohort IDs based on matching results
                let sectionId: UUID
                var cohortId: UUID

                if let section = matchedSection {
                    // Found a matchable section - use it
                    sectionId = section.id ?? UUID()
                    cohortId = section.cohortId ?? UUID()
                    if needsManualReview {
                        unmatchedSectionCode = "⚠️ Multiple sections: \(sectionField)"
                    } else {
                        unmatchedSectionCode = nil
                    }
                } else if needsManualReview {
                    // Flag for manual review with special message
                    sectionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
                    cohortId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
                    unmatchedSectionCode = "⚠️ Multiple sections: \(sectionField)"
                } else if actualSectionCode.isEmpty {
                    // No section code provided
                    sectionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
                    cohortId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
                    unmatchedSectionCode = "⚠️ No section code"
                } else {
                    // Section code didn't match any section in the course
                    sectionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
                    cohortId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
                    unmatchedSectionCode = actualSectionCode
                }

                // Assign a real cohort to ALL students
                if randomlyAssignCohorts {
                    // Random assignment - distribute evenly
                    let assignedCohort = availableCohorts[cohortIndex % availableCohorts.count]
                    cohortId = assignedCohort.id ?? UUID()
                    cohortIndex += 1
                } else {
                    // Not random - fetch first custom cohort for students without a matched section
                    if matchedSection == nil {
                        let cohortRequest = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
                        cohortRequest.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
                        cohortRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

                        if let allCohortsForFallback = try? context.fetch(cohortRequest) {
                            // Filter to only custom cohorts (exclude "All Students")
                            let customCohortsForFallback = allCohortsForFallback.filter { cohort in
                                let isDefault = cohort.value(forKey: "isDefault") as? Bool ?? false
                                let name = cohort.name ?? ""
                                return !isDefault && name != "All Students"
                            }

                            if let firstCohort = customCohortsForFallback.first {
                                cohortId = firstCohort.id ?? UUID()
                            }
                        }
                    }
                }

                if let existingStudent = try context.fetch(studentRequest).first {
                    // Update existing student
                    existingStudent.fullName = fullName
                    existingStudent.email = email
                    existingStudent.sectionId = sectionId
                    existingStudent.cohortId = cohortId
                    existingStudent.unmatchedSectionCode = unmatchedSectionCode
                    successCount += 1
                } else {
                    // Create new student
                    let student = Student(
                        id: UUID(),
                        courseId: courseId,
                        sectionId: sectionId,
                        sisUserId: sisUserId,
                        email: email,
                        fullName: fullName,
                        cohortId: cohortId,
                        slackUserId: nil,
                        slackUsername: nil,
                        isActive: true,
                        unmatchedSectionCode: unmatchedSectionCode
                    )
                    _ = StudentEntity.create(from: student, in: context)
                    successCount += 1
                }
            }

            try context.save()

            return ImportResult(
                successCount: successCount,
                failureCount: failureCount,
                errors: errors
            )
        }
    }

    func randomlyReassignCohorts(courseId: UUID) async throws -> Int {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform(schedule: .enqueued) {
            // Fetch all cohorts for the course
            let cohortRequest = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
            cohortRequest.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
            cohortRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            let allCohorts = try context.fetch(cohortRequest)

            // Filter to only custom cohorts (exclude "All Students" by flag AND name)
            var cohorts = allCohorts.filter { cohort in
                let isDefault = cohort.value(forKey: "isDefault") as? Bool ?? false
                let name = cohort.name ?? ""
                return !isDefault && name != "All Students"
            }

            guard !cohorts.isEmpty else {
                throw RepositoryError.notFound
            }

            // Shuffle cohorts for random distribution
            cohorts.shuffle()

            // Fetch all students for the course
            let studentRequest = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
            studentRequest.predicate = NSPredicate(format: "courseId == %@ AND isActive == YES", courseId as CVarArg)
            studentRequest.sortDescriptors = [NSSortDescriptor(key: "fullName", ascending: true)]
            let students = try context.fetch(studentRequest)

            // Assign students to cohorts in round-robin fashion for even distribution
            for (index, student) in students.enumerated() {
                let cohort = cohorts[index % cohorts.count]
                student.cohortId = cohort.id
            }

            try context.save()

            return students.count
        }
    }

    func fixInvalidCohortAssignments(courseId: UUID) async throws -> Int {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform(schedule: .enqueued) {
            // Fetch all cohorts
            let cohortRequest = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
            cohortRequest.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
            cohortRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
            let allCohorts = try context.fetch(cohortRequest)

            // Filter to only custom cohorts (exclude "All Students" by flag AND name)
            let customCohorts = allCohorts.filter { cohort in
                let isDefault = cohort.value(forKey: "isDefault") as? Bool ?? false
                let name = cohort.name ?? ""
                return !isDefault && name != "All Students"
            }

            guard !customCohorts.isEmpty else {
                throw RepositoryError.notFound
            }

            // Find ALL "All Students" cohort IDs (by flag or name)
            let allStudentsCohortIds = allCohorts.filter { cohort in
                let isDefault = cohort.value(forKey: "isDefault") as? Bool ?? false
                let name = cohort.name ?? ""
                return isDefault || name == "All Students"
            }.compactMap { $0.id }

            // Fetch students with invalid cohort assignments
            let studentRequest = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
            studentRequest.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
            studentRequest.sortDescriptors = [NSSortDescriptor(key: "fullName", ascending: true)]

            let allStudents = try context.fetch(studentRequest)

            // Filter to students with invalid cohort IDs and assign them
            var fixedCount = 0
            var assignmentIndex = 0
            let placeholderUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
            let validCohortIds = Set(customCohorts.compactMap { $0.id })

            for student in allStudents {
                guard let studentCohortId = student.cohortId else {
                    // Student has no cohort ID - assign one
                    let assignedCohort = customCohorts[assignmentIndex % customCohorts.count]
                    student.cohortId = assignedCohort.id
                    fixedCount += 1
                    assignmentIndex += 1
                    continue
                }

                let needsFix = allStudentsCohortIds.contains(studentCohortId) ||
                               studentCohortId == placeholderUUID ||
                               !validCohortIds.contains(studentCohortId)

                if needsFix {
                    // Assign to a custom cohort using round-robin
                    let assignedCohort = customCohorts[assignmentIndex % customCohorts.count]
                    student.cohortId = assignedCohort.id
                    fixedCount += 1
                    assignmentIndex += 1
                }
            }

            try context.save()

            return fixedCount
        }
    }
}
