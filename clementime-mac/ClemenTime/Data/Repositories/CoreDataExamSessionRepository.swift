//
//  CoreDataExamSessionRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

class CoreDataExamSessionRepository: ExamSessionRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchExamSessions(courseId: UUID) async throws -> [ExamSession] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSessionEntity>(entityName: "ExamSessionEntity")
        request.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "examNumber", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchExamSession(courseId: UUID, examNumber: Int) async throws -> ExamSession? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSessionEntity>(entityName: "ExamSessionEntity")
        request.predicate = NSPredicate(format: "courseId == %@ AND examNumber == %d", courseId as CVarArg, examNumber)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func fetchExamSession(id: UUID) async throws -> ExamSession? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSessionEntity>(entityName: "ExamSessionEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createExamSession(_ session: ExamSession) async throws -> ExamSession {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = ExamSessionEntity.create(from: session, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateExamSession(_ session: ExamSession) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ExamSessionEntity>(entityName: "ExamSessionEntity")
            request.predicate = NSPredicate(format: "id == %@", session.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: session)
            try context.save()
        }
    }

    func deleteExamSession(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ExamSessionEntity>(entityName: "ExamSessionEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }
}
