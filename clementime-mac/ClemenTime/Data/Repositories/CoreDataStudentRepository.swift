//
//  CoreDataStudentRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

class CoreDataStudentRepository: StudentRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchStudents(courseId: UUID) async throws -> [Student] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "courseId == %@ AND isActive == YES", courseId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "fullName", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchStudents(sectionId: UUID) async throws -> [Student] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "sectionId == %@ AND isActive == YES", sectionId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "fullName", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchStudent(id: UUID) async throws -> Student? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
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

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createStudent(_ student: Student) async throws -> Student {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = StudentEntity.create(from: student, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateStudent(_ student: Student) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
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

        try await context.perform {
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

    func importStudents(from csvURL: URL, courseId: UUID) async throws -> ImportResult {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            // Read CSV file
            let csvData = try String(contentsOf: csvURL, encoding: .utf8)
            let lines = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count > 1 else {
                throw RepositoryError.invalidData
            }

            // Parse header
            let header = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            // Find column indices
            guard let sisIdIndex = header.firstIndex(where: { $0.lowercased().contains("sis") || $0.lowercased() == "id" }),
                  let nameIndex = header.firstIndex(where: { $0.lowercased().contains("name") }),
                  let emailIndex = header.firstIndex(where: { $0.lowercased().contains("email") }),
                  let sectionIndex = header.firstIndex(where: { $0.lowercased().contains("section") }) else {
                throw RepositoryError.invalidData
            }

            var created = 0
            var updated = 0
            var errors: [String] = []

            // Process each row
            for (index, line) in lines.enumerated() where index > 0 {
                let fields = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                guard fields.count > max(sisIdIndex, nameIndex, emailIndex, sectionIndex) else {
                    errors.append("Line \(index): Invalid field count")
                    continue
                }

                let sisUserId = fields[sisIdIndex]
                let fullName = fields[nameIndex]
                let email = fields[emailIndex]
                let sectionCode = fields[sectionIndex]

                // Find or create student
                let studentRequest = NSFetchRequest<StudentEntity>(entityName: "StudentEntity")
                studentRequest.predicate = NSPredicate(format: "sisUserId == %@ AND courseId == %@", sisUserId, courseId as CVarArg)
                studentRequest.fetchLimit = 1

                // Find section
                let sectionRequest = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
                sectionRequest.predicate = NSPredicate(format: "code == %@ AND courseId == %@", sectionCode, courseId as CVarArg)
                sectionRequest.fetchLimit = 1

                guard let section = try context.fetch(sectionRequest).first else {
                    errors.append("Line \(index): Section '\(sectionCode)' not found")
                    continue
                }

                if let existingStudent = try context.fetch(studentRequest).first {
                    // Update existing student
                    existingStudent.fullName = fullName
                    existingStudent.email = email
                    existingStudent.sectionId = section.id ?? UUID()
                    existingStudent.cohortId = section.cohortId ?? UUID()
                    updated += 1
                } else {
                    // Create new student
                    let student = Student(
                        id: UUID(),
                        courseId: courseId,
                        sectionId: section.id ?? UUID(),
                        sisUserId: sisUserId,
                        email: email,
                        fullName: fullName,
                        cohortId: section.cohortId ?? UUID(),
                        slackUserId: nil,
                        slackUsername: nil,
                        isActive: true
                    )
                    _ = StudentEntity.create(from: student, in: context)
                    created += 1
                }
            }

            try context.save()

            return ImportResult(
                totalRows: lines.count - 1,
                created: created,
                updated: updated,
                errors: errors
            )
        }
    }
}
