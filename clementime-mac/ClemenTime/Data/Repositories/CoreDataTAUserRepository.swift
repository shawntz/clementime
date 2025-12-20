//
//  CoreDataTAUserRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
@preconcurrency import CoreData

class CoreDataTAUserRepository: TAUserRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchTAUsers(courseId: UUID) async throws -> [TAUser] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TAUserEntity>(entityName: "TAUserEntity")
        request.predicate = NSPredicate(format: "courseId == %@ AND isActive == YES", courseId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastName", ascending: true),
            NSSortDescriptor(key: "firstName", ascending: true)
        ]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchTAUser(id: UUID) async throws -> TAUser? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TAUserEntity>(entityName: "TAUserEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func fetchTAUser(email: String, courseId: UUID) async throws -> TAUser? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<TAUserEntity>(entityName: "TAUserEntity")
        request.predicate = NSPredicate(format: "email == %@ AND courseId == %@", email, courseId as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createTAUser(_ taUser: TAUser) async throws -> TAUser {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = TAUserEntity.create(from: taUser, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateTAUser(_ taUser: TAUser) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<TAUserEntity>(entityName: "TAUserEntity")
            request.predicate = NSPredicate(format: "id == %@", taUser.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: taUser)
            try context.save()
        }
    }

    func deleteTAUser(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<TAUserEntity>(entityName: "TAUserEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }

    func updatePermissions(taUserId: UUID, permissions: [Permission]) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<TAUserEntity>(entityName: "TAUserEntity")
            request.predicate = NSPredicate(format: "id == %@", taUserId as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.permissionsJSON = Permission.encode(permissions)
            try context.save()
        }
    }
}
