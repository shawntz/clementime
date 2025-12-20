//
//  CoreDataScheduleRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
@preconcurrency import CoreData

class CoreDataScheduleRepository: ScheduleRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchExamSlots(courseId: UUID) async throws -> [ExamSlot] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
        request.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: true),
            NSSortDescriptor(key: "startTime", ascending: true)
        ]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchExamSlots(courseId: UUID, examNumber: Int) async throws -> [ExamSlot] {
        let context = persistentContainer.viewContext

        // First, fetch the exam session
        let sessionRequest = NSFetchRequest<ExamSessionEntity>(entityName: "ExamSessionEntity")
        sessionRequest.predicate = NSPredicate(format: "courseId == %@ AND examNumber == %d", courseId as CVarArg, examNumber)
        sessionRequest.fetchLimit = 1

        return try await context.perform {
            guard let session = try context.fetch(sessionRequest).first else {
                return []
            }

            // Fetch slots for this exam session
            let slotsRequest = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
            slotsRequest.predicate = NSPredicate(format: "examSessionId == %@", session.id! as CVarArg)
            slotsRequest.sortDescriptors = [
                NSSortDescriptor(key: "date", ascending: true),
                NSSortDescriptor(key: "startTime", ascending: true)
            ]

            let entities = try context.fetch(slotsRequest)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchExamSlots(studentId: UUID) async throws -> [ExamSlot] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
        request.predicate = NSPredicate(format: "studentId == %@", studentId as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: true),
            NSSortDescriptor(key: "startTime", ascending: true)
        ]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchExamSlot(id: UUID) async throws -> ExamSlot? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func generateSchedule(courseId: UUID, startingFromExam: Int?) async throws -> ScheduleResult {
        // This will be implemented by the GenerateScheduleUseCase
        // The use case will use this repository to save the generated exam slots
        throw RepositoryError.notImplemented
    }

    func updateExamSlot(_ slot: ExamSlot) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
            request.predicate = NSPredicate(format: "id == %@", slot.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            // Save history before updating
            try self.createHistory(for: entity, reason: "Manual update", changedBy: "User", in: context)

            entity.update(from: slot)
            try context.save()
        }
    }

    func lockExamSlot(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.isLocked = true
            try context.save()
        }
    }

    func unlockExamSlot(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.isLocked = false
            try context.save()
        }
    }

    func swapExamSlots(slot1Id: UUID, slot2Id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
            request.predicate = NSPredicate(format: "id IN %@", [slot1Id, slot2Id])

            let entities = try context.fetch(request)
            guard entities.count == 2,
                  let slot1 = entities.first(where: { $0.id == slot1Id }),
                  let slot2 = entities.first(where: { $0.id == slot2Id }) else {
                throw RepositoryError.notFound
            }

            // Save history for both slots
            try self.createHistory(for: slot1, reason: "Swapped with another student", changedBy: "User", in: context)
            try self.createHistory(for: slot2, reason: "Swapped with another student", changedBy: "User", in: context)

            // Swap times
            let tempStartTime = slot1.startTime
            let tempEndTime = slot1.endTime
            let tempDate = slot1.date

            slot1.startTime = slot2.startTime
            slot1.endTime = slot2.endTime
            slot1.date = slot2.date

            slot2.startTime = tempStartTime
            slot2.endTime = tempEndTime
            slot2.date = tempDate

            try context.save()
        }
    }

    func fetchExamSlotHistory(studentId: UUID) async throws -> [ExamSlotHistory] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSlotHistoryEntity>(entityName: "ExamSlotHistoryEntity")
        request.predicate = NSPredicate(format: "studentId == %@", studentId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "changedAt", ascending: false)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchExamSlotHistory(examSlotId: UUID) async throws -> [ExamSlotHistory] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<ExamSlotHistoryEntity>(entityName: "ExamSlotHistoryEntity")
        request.predicate = NSPredicate(format: "examSlotId == %@", examSlotId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "changedAt", ascending: false)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    // MARK: - Private Helpers

    private func createHistory(for slot: ExamSlotEntity, reason: String, changedBy: String, in context: NSManagedObjectContext) throws {
        let history = ExamSlotHistory(
            id: UUID(),
            examSlotId: slot.id ?? UUID(),
            studentId: slot.studentId ?? UUID(),
            sectionId: slot.sectionId ?? UUID(),
            examNumber: 0, // This should be fetched from exam session
            weekNumber: 0, // This should be calculated
            date: slot.date,
            startTime: slot.startTime,
            endTime: slot.endTime,
            isScheduled: slot.isScheduled,
            changedAt: Date(),
            changedBy: changedBy,
            reason: reason
        )

        _ = ExamSlotHistoryEntity.create(from: history, in: context)
    }
}
