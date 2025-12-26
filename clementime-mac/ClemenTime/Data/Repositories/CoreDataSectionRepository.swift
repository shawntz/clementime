//
//  CoreDataSectionRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
@preconcurrency import CoreData

class CoreDataSectionRepository: SectionRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchSections(courseId: UUID) async throws -> [Section] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
        request.predicate = NSPredicate(format: "courseId == %@ AND isActive == YES", courseId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "code", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchSections(cohortId: UUID) async throws -> [Section] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
        request.predicate = NSPredicate(format: "cohortId == %@ AND isActive == YES", cohortId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "code", ascending: true)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchSection(id: UUID) async throws -> Section? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createSection(_ section: Section) async throws -> Section {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            let entity = SectionEntity.create(from: section, in: context)
            try context.save()
            return entity.toDomain()
        }
    }

    func updateSection(_ section: Section) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
            request.predicate = NSPredicate(format: "id == %@", section.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: section)
            try context.save()
        }
    }

    func deleteSection(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            context.delete(entity)
            try context.save()
        }
    }

    func assignTA(taUserId: UUID, toSectionId: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
            request.predicate = NSPredicate(format: "id == %@", toSectionId as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.assignedTAId = taUserId
            try context.save()
        }
    }

    func unassignTA(fromSectionId: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<SectionEntity>(entityName: "SectionEntity")
            request.predicate = NSPredicate(format: "id == %@", fromSectionId as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.assignedTAId = nil
            try context.save()
        }
    }
}
