//
//  CoreDataCourseRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

class CoreDataCourseRepository: CourseRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchCourses() async throws -> [Course] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<CourseEntity>(entityName: "CourseEntity")
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchCourse(id: UUID) async throws -> Course? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<CourseEntity>(entityName: "CourseEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createCourse(_ course: Course) async throws -> Course {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = CourseEntity.create(from: course, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateCourse(_ course: Course) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<CourseEntity>(entityName: "CourseEntity")
            request.predicate = NSPredicate(format: "id == %@", course.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: course)
            try context.save()
        }
    }

    func deleteCourse(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<CourseEntity>(entityName: "CourseEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }

    func shareCourse(_ courseId: UUID, with email: String, permissions: [Permission]) async throws -> URL {
        // TODO: Implement CloudKit sharing
        // This will be implemented in the CloudKitShareManager
        throw RepositoryError.notImplemented
    }

    func acceptShare(metadata: Any) async throws {
        // TODO: Implement CloudKit share acceptance
        // This will be implemented in the CloudKitShareManager
        throw RepositoryError.notImplemented
    }
}

// MARK: - Repository Errors
enum RepositoryError: Error {
    case notFound
    case notImplemented
    case invalidData
    case saveFailed
}
