//
//  Recording.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct Recording: Identifiable, Codable, Hashable {
    let id: UUID
    let examSlotId: UUID
    let studentId: UUID
    let taUserId: UUID
    var recordedAt: Date
    var uploadedAt: Date?
    var duration: TimeInterval
    var fileSize: Int64
    var localFileURL: String?
    var iCloudAssetName: String?

    init(
        id: UUID = UUID(),
        examSlotId: UUID,
        studentId: UUID,
        taUserId: UUID,
        recordedAt: Date = Date(),
        uploadedAt: Date? = nil,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        localFileURL: String? = nil,
        iCloudAssetName: String? = nil
    ) {
        self.id = id
        self.examSlotId = examSlotId
        self.studentId = studentId
        self.taUserId = taUserId
        self.recordedAt = recordedAt
        self.uploadedAt = uploadedAt
        self.duration = duration
        self.fileSize = fileSize
        self.localFileURL = localFileURL
        self.iCloudAssetName = iCloudAssetName
    }

    // Computed properties
    var isUploaded: Bool {
        uploadedAt != nil && iCloudAssetName != nil
    }

    var hasLocalFile: Bool {
        localFileURL != nil
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var statusDescription: String {
        if isUploaded {
            return "Uploaded to iCloud"
        } else if hasLocalFile {
            return "Local only"
        } else {
            return "No file"
        }
    }
}
