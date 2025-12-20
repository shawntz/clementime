//
//  RecordingEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension RecordingEntity {
    func toDomain() -> Recording {
        Recording(
            id: id ?? UUID(),
            examSlotId: examSlotId ?? UUID(),
            studentId: studentId ?? UUID(),
            taUserId: taUserId ?? UUID(),
            recordedAt: recordedAt ?? Date(),
            uploadedAt: uploadedAt,
            duration: duration,
            fileSize: fileSize,
            localFileURL: localFileURL,
            iCloudAssetName: iCloudAssetName
        )
    }

    func update(from domain: Recording) {
        self.id = domain.id
        self.examSlotId = domain.examSlotId
        self.studentId = domain.studentId
        self.taUserId = domain.taUserId
        self.recordedAt = domain.recordedAt
        self.uploadedAt = domain.uploadedAt
        self.duration = domain.duration
        self.fileSize = domain.fileSize
        self.localFileURL = domain.localFileURL
        self.iCloudAssetName = domain.iCloudAssetName
    }

    static func create(from domain: Recording, in context: NSManagedObjectContext) -> RecordingEntity {
        let entity = RecordingEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
