//
//  CoreDataConstraintRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
@preconcurrency import CoreData

class CoreDataConstraintRepository: ConstraintRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchConstraints(studentId: UUID) async throws -> [Constraint] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ConstraintEntity>(entityName: "ConstraintEntity")
        request.predicate = NSPredicate(format: "studentId == %@", studentId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "constraintType", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchActiveConstraints(studentId: UUID) async throws -> [Constraint] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ConstraintEntity>(entityName: "ConstraintEntity")
        request.predicate = NSPredicate(format: "studentId == %@ AND isActive == YES", studentId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "constraintType", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchConstraint(id: UUID) async throws -> Constraint? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ConstraintEntity>(entityName: "ConstraintEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createConstraint(_ constraint: Constraint) async throws -> Constraint {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = ConstraintEntity.create(from: constraint, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateConstraint(_ constraint: Constraint) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ConstraintEntity>(entityName: "ConstraintEntity")
            request.predicate = NSPredicate(format: "id == %@", constraint.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: constraint)
            try context.save()
        }
    }

    func deleteConstraint(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ConstraintEntity>(entityName: "ConstraintEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }

    func toggleConstraint(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ConstraintEntity>(entityName: "ConstraintEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.isActive.toggle()
            try context.save()
        }
    }
}
