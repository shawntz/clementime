//
//  CoreDataRecordingRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
@preconcurrency import CoreData
import CloudKit

class CoreDataRecordingRepository: RecordingRepository {
    private let persistentContainer: NSPersistentCloudKitContainer
    private let cloudKitContainer: CKContainer?
    private let cloudKitEnabled: Bool

    init(persistentContainer: NSPersistentCloudKitContainer, cloudKitEnabled: Bool) {
        self.persistentContainer = persistentContainer
        self.cloudKitEnabled = cloudKitEnabled
        self.cloudKitContainer = cloudKitEnabled ? CKContainer(identifier: "iCloud.com.shawnschwartz.clementime") : nil
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
        guard cloudKitEnabled, let cloudKitContainer else {
            throw RecordingError.cloudKitUnavailable
        }
        // Fetch the recording from Core Data
        guard let recording = try await fetchRecording(id: recordingId) else {
            throw RepositoryError.notFound
        }

        // Get the local file URL
        guard let localPath = recording.localFileURL,
              let localURL = URL(string: localPath) else {
            throw RecordingError.noLocalFile
        }

        // Verify the file exists
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw RecordingError.fileNotFound
        }

        // Create a CKAsset from the local file
        let asset = CKAsset(fileURL: localURL)

        // Create a CKRecord for the recording
        let recordID = CKRecord.ID(recordName: recording.id.uuidString)
        let record = CKRecord(recordType: "Recording", recordID: recordID)
        record["audioFile"] = asset
        record["examSlotId"] = recording.examSlotId.uuidString
        record["studentId"] = recording.studentId.uuidString
        record["taUserId"] = recording.taUserId.uuidString
        record["recordedAt"] = recording.recordedAt
        record["duration"] = recording.duration
        record["fileSize"] = recording.fileSize

        // Save to CloudKit
        let database = cloudKitContainer.privateCloudDatabase
        _ = try await database.save(record)

        // Update the recording entity to mark it as uploaded
        var updatedRecording = recording
        updatedRecording.uploadedAt = Date()
        updatedRecording.iCloudAssetName = recording.id.uuidString
        try await updateRecording(updatedRecording)
    }

    func downloadFromiCloud(_ recordingId: UUID) async throws -> URL {
        guard cloudKitEnabled, let cloudKitContainer else {
            throw RecordingError.cloudKitUnavailable
        }
        // Fetch the recording metadata from Core Data
        guard let recording = try await fetchRecording(id: recordingId) else {
            throw RepositoryError.notFound
        }

        // Verify it has been uploaded to iCloud
        guard let assetName = recording.iCloudAssetName else {
            throw RecordingError.notUploadedToiCloud
        }

        // Fetch the record from CloudKit
        let recordID = CKRecord.ID(recordName: assetName)
        let database = cloudKitContainer.privateCloudDatabase
        let record = try await database.record(for: recordID)

        // Get the asset from the record
        guard let asset = record["audioFile"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw RecordingError.assetNotFound
        }

        // Create local file path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingPath = documentsPath.appendingPathComponent("recordings")

        // Create recordings directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: recordingPath.path) {
            try FileManager.default.createDirectory(at: recordingPath, withIntermediateDirectories: true)
        }

        let fileName = "\(recording.id.uuidString).m4a"
        let localURL = recordingPath.appendingPathComponent(fileName)

        // Copy the file from the CloudKit cache to our local directory
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        try FileManager.default.copyItem(at: fileURL, to: localURL)

        // Update the recording entity with the local file path
        var updatedRecording = recording
        updatedRecording.localFileURL = localURL.path
        try await updateRecording(updatedRecording)

        return localURL
    }
}

// MARK: - Recording Errors

enum RecordingError: LocalizedError {
    case noLocalFile
    case fileNotFound
    case notUploadedToiCloud
    case assetNotFound
    case cloudKitUnavailable

    var errorDescription: String? {
        switch self {
        case .noLocalFile:
            return "Recording has no local file URL"
        case .fileNotFound:
            return "Recording file not found at specified path"
        case .notUploadedToiCloud:
            return "Recording has not been uploaded to iCloud"
        case .assetNotFound:
            return "iCloud asset not found in CloudKit record"
        case .cloudKitUnavailable:
            return "iCloud features are not available in this build"
        }
    }
}
