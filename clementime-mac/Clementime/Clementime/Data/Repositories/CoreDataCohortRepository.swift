//
//  CoreDataCohortRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
@preconcurrency import CoreData

class CoreDataCohortRepository: CohortRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchCohorts(courseId: UUID) async throws -> [Cohort] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
        request.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchCohort(id: UUID) async throws -> Cohort? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createCohort(_ cohort: Cohort) async throws -> Cohort {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = CohortEntity.create(from: cohort, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateCohort(_ cohort: Cohort) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
            request.predicate = NSPredicate(format: "id == %@", cohort.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: cohort)
            try context.save()
        }
    }

    func deleteCohort(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }

    func reorderCohorts(_ cohorts: [Cohort]) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            for (index, cohort) in cohorts.enumerated() {
                let request = NSFetchRequest<CohortEntity>(entityName: "CohortEntity")
                request.predicate = NSPredicate(format: "id == %@", cohort.id as CVarArg)
                request.fetchLimit = 1

                if let entity = try context.fetch(request).first {
                    entity.sortOrder = Int16(index)
                }
            }

            try context.save()
        }
    }
}
