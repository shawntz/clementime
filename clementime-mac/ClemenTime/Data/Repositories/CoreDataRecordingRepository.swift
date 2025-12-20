//
//  CoreDataRecordingRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

class CoreDataRecordingRepository: RecordingRepository {
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
    }

    func fetchRecordings(courseId: UUID) async throws -> [Recording] {
        let context = persistentContainer.viewContext

        // Fetch exam slots for the course
        let slotRequest = NSFetchRequest<ExamSlotEntity>(entityName: "ExamSlotEntity")
        slotRequest.predicate = NSPredicate(format: "courseId == %@", courseId as CVarArg)

        return try await context.perform {
            let slots = try context.fetch(slotRequest)
            let slotIds = slots.compactMap { $0.id }

            guard !slotIds.isEmpty else {
                return []
            }

            let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
            request.predicate = NSPredicate(format: "examSlotId IN %@", slotIds)
            request.sortDescriptors = [NSSortDescriptor(key: "recordedAt", ascending: false)]

            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchRecordings(studentId: UUID) async throws -> [Recording] {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        request.predicate = NSPredicate(format: "studentId == %@", studentId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "recordedAt", ascending: false)]

        return try await context.perform {
            let entities = try context.fetch(request)
            return entities.map { $0.toDomain() }
        }
    }

    func fetchRecording(examSlotId: UUID) async throws -> Recording? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        request.predicate = NSPredicate(format: "examSlotId == %@", examSlotId as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func fetchRecording(id: UUID) async throws -> Recording? {
        let context = persistentContainer.viewContext
        let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        return try await context.perform {
            guard let entity = try context.fetch(request).first else {
                return nil
            }
            return entity.toDomain()
        }
    }

    func createRecording(_ recording: Recording, audioData: Data) async throws -> Recording {
        let context = persistentContainer.newBackgroundContext()

        return try await context.perform {
            // Save audio data to local file
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let recordingPath = documentsPath.appendingPathComponent("recordings")

            // Create recordings directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: recordingPath.path) {
                try FileManager.default.createDirectory(at: recordingPath, withIntermediateDirectories: true)
            }

            let fileName = "\(recording.id.uuidString).m4a"
            let fileURL = recordingPath.appendingPathComponent(fileName)

            try audioData.write(to: fileURL)

            // Create recording entity with local file path
            var updatedRecording = recording
            updatedRecording.localFileURL = fileURL.path
            updatedRecording.fileSize = Int64(audioData.count)

            let entity = RecordingEntity.create(from: updatedRecording, in: context)
            try context.save()

            return entity.toDomain()
        }
    }

    func updateRecording(_ recording: Recording) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
            request.predicate = NSPredicate(format: "id == %@", recording.id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            entity.update(from: recording)
            try context.save()
        }
    }

    func deleteRecording(id: UUID) async throws {
        let context = persistentContainer.newBackgroundContext()

        try await context.perform {
            let request = NSFetchRequest<RecordingEntity>(entityName: "RecordingEntity")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                throw RepositoryError.notFound
            }

            // Delete local file if it exists
            if let localPath = entity.localFileURL,
               let fileURL = URL(string: localPath) {
                try? FileManager.default.removeItem(at: fileURL)
            }

            context.delete(entity)
            try context.save()
        }
    }

    func uploadToiCloud(_ recordingId: UUID) async throws {
        // TODO: Implement iCloud upload using CKAsset
        // This will be implemented in the iCloudRecordingManager
        throw RepositoryError.notImplemented
    }

    func downloadFromiCloud(_ recordingId: UUID) async throws -> URL {
        // TODO: Implement iCloud download using CKAsset
        // This will be implemented in the iCloudRecordingManager
        throw RepositoryError.notImplemented
    }
}
