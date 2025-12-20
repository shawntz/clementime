//
//  CloudKitShareManager.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import CloudKit
import CoreData

class CloudKitShareManager {
    private let container: CKContainer
    private let persistentContainer: NSPersistentCloudKitContainer

    init(persistentContainer: NSPersistentCloudKitContainer) {
        self.persistentContainer = persistentContainer
        self.container = CKContainer(identifier: "iCloud.com.shawnschwartz.clementime")
    }

    // MARK: - Share Creation

    /// Create a share for a course and invite a collaborator
    func shareCourse(
        _ courseId: UUID,
        with email: String,
        permissions: [Permission]
    ) async throws -> URL {
        // 1. Fetch the course record from CloudKit
        let recordID = CKRecord.ID(recordName: courseId.uuidString)
        let courseRecord = try await container.privateCloudDatabase.record(for: recordID)

        // 2. Create or fetch existing share
        let share: CKShare
        if let existingShare = try? await fetchShare(for: courseRecord) {
            share = existingShare
        } else {
            share = CKShare(rootRecord: courseRecord)
            share[CKShare.SystemFieldKey.title] = courseRecord["name"] as? String
        }

        // 3. Set share permissions (all participants will have read/write)
        share.publicPermission = .none // Private sharing only

        // 4. Save share to CloudKit
        // Note: In modern CloudKit, we don't manually add participants.
        // Instead, we save the share and send the URL to the collaborator.
        // They accept the share by opening the URL.
        let (savedRecords, _) = try await container.privateCloudDatabase.modifyRecords(
            saving: [courseRecord, share],
            deleting: []
        )

        // Extract the saved share from results
        var savedShare: CKShare?
        for (_, result) in savedRecords {
            if case .success(let record) = result, record is CKShare {
                savedShare = record as? CKShare
                break
            }
        }

        guard let share = savedShare else {
            throw CloudKitError.shareSaveFailed
        }

        // 7. Create TAUser record for this collaborator with custom permissions
        try await createTAUserRecord(
            courseId: courseId,
            email: email,
            permissions: permissions
        )

        // 8. Return share URL
        guard let shareURL = share.url else {
            throw CloudKitError.shareURLNotFound
        }

        return shareURL
    }

    /// Accept a share invitation
    func acceptShare(metadata: CKShare.Metadata) async throws {
        // 1. Accept the share
        _ = try await container.accept(metadata)

        // 2. Fetch the shared course record
        guard let rootRecord = metadata.rootRecord else {
            throw CloudKitError.rootRecordNotFound
        }

        let sharedDatabase = container.sharedCloudDatabase
        let courseRecord = try await sharedDatabase.record(for: rootRecord.recordID)

        // 3. The course will automatically sync to Core Data via NSPersistentCloudKitContainer
        // No manual Core Data creation needed - CloudKit sync handles it

        print("Successfully accepted share for course: \(courseRecord["name"] ?? "Unknown")")
    }

    /// Remove a participant from a course share
    func removeParticipant(email: String, from courseId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: courseId.uuidString)
        let courseRecord = try await container.privateCloudDatabase.record(for: recordID)

        guard let share = try? await fetchShare(for: courseRecord) else {
            throw CloudKitError.shareNotFound
        }

        // Find and remove participant
        if let participant = share.participants.first(where: {
            $0.userIdentity.lookupInfo?.emailAddress == email
        }) {
            share.removeParticipant(participant)

            // Save updated share
            try await container.privateCloudDatabase.save(share)

            // Also delete the TAUser record
            try await deleteTAUserRecord(email: email, courseId: courseId)
        }
    }

    /// Stop sharing a course (remove all participants)
    func stopSharing(courseId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: courseId.uuidString)
        let courseRecord = try await container.privateCloudDatabase.record(for: recordID)

        guard let share = try? await fetchShare(for: courseRecord) else {
            return // No share exists
        }

        // Delete the share
        try await container.privateCloudDatabase.deleteRecord(withID: share.recordID)
    }

    // MARK: - Private Helpers

    private func fetchShare(for record: CKRecord) async throws -> CKShare {
        guard let shareReference = record.share else {
            throw CloudKitError.shareNotFound
        }

        return try await container.privateCloudDatabase.record(for: shareReference.recordID) as! CKShare
    }

    private func createTAUserRecord(
        courseId: UUID,
        email: String,
        permissions: [Permission]
    ) async throws {
        let taUserId = UUID()
        let recordID = CKRecord.ID(recordName: taUserId.uuidString)
        let taUserRecord = CKRecord(recordType: "TAUserEntity", recordID: recordID)

        // Extract name from email (will be updated when TA accepts)
        let nameParts = email.components(separatedBy: "@").first?
            .components(separatedBy: ".") ?? ["Unknown"]

        taUserRecord["id"] = taUserId.uuidString
        taUserRecord["courseId"] = courseId.uuidString
        taUserRecord["email"] = email
        taUserRecord["firstName"] = nameParts.first?.capitalized ?? "Unknown"
        taUserRecord["lastName"] = nameParts.count > 1 ? nameParts[1].capitalized : "User"
        taUserRecord["username"] = email
        taUserRecord["role"] = "ta"
        taUserRecord["isActive"] = true
        taUserRecord["location"] = ""

        // Encode permissions to JSON
        let encoder = JSONEncoder()
        if let permissionsData = try? encoder.encode(permissions),
           let permissionsJSON = String(data: permissionsData, encoding: .utf8) {
            taUserRecord["permissionsJSON"] = permissionsJSON
        } else {
            taUserRecord["permissionsJSON"] = "[]"
        }

        // Save to private database
        try await container.privateCloudDatabase.save(taUserRecord)
    }

    private func deleteTAUserRecord(email: String, courseId: UUID) async throws {
        // Query for TAUser with this email and courseId
        let predicate = NSPredicate(
            format: "email == %@ AND courseId == %@",
            email,
            courseId as CVarArg
        )
        let query = CKQuery(recordType: "TAUserEntity", predicate: predicate)

        let results = try await container.privateCloudDatabase.records(matching: query)

        // Delete all matching records
        for (recordID, _) in results.matchResults {
            try await container.privateCloudDatabase.deleteRecord(withID: recordID)
        }
    }

    // MARK: - Share Discovery

    /// Fetch all shares for courses owned by the current user
    func fetchShares(for courseId: UUID) async throws -> [CKShare.Participant] {
        let recordID = CKRecord.ID(recordName: courseId.uuidString)
        let courseRecord = try await container.privateCloudDatabase.record(for: recordID)

        guard let share = try? await fetchShare(for: courseRecord) else {
            return []
        }

        return share.participants.filter { $0.role == .privateUser }
    }

    /// Check if current user is owner of a course
    func isOwner(of courseId: UUID) async throws -> Bool {
        let recordID = CKRecord.ID(recordName: courseId.uuidString)

        do {
            _ = try await container.privateCloudDatabase.record(for: recordID)
            return true // Record exists in private database, user is owner
        } catch {
            // Check if it exists in shared database
            do {
                _ = try await container.sharedCloudDatabase.record(for: recordID)
                return false // Record exists in shared database, user is collaborator
            } catch {
                throw CloudKitError.recordNotFound
            }
        }
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: Error, LocalizedError {
    case participantNotFound
    case shareSaveFailed
    case shareURLNotFound
    case shareNotFound
    case rootRecordNotFound
    case recordNotFound

    var errorDescription: String? {
        switch self {
        case .participantNotFound:
            return "Could not find user with the provided email. They may need to sign in to iCloud."
        case .shareSaveFailed:
            return "Failed to create share in iCloud."
        case .shareURLNotFound:
            return "Share was created but URL is missing."
        case .shareNotFound:
            return "No share exists for this course."
        case .rootRecordNotFound:
            return "Share root record not found."
        case .recordNotFound:
            return "Course record not found in iCloud."
        }
    }
}
