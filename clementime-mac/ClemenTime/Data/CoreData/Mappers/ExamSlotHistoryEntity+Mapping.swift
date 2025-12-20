//
//  ExamSlotHistoryEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension ExamSlotHistoryEntity {
    func toDomain() -> ExamSlotHistory {
        ExamSlotHistory(
            id: id ?? UUID(),
            examSlotId: examSlotId ?? UUID(),
            studentId: studentId ?? UUID(),
            sectionId: sectionId ?? UUID(),
            examNumber: Int(examNumber),
            weekNumber: Int(weekNumber),
            date: date,
            startTime: startTime,
            endTime: endTime,
            isScheduled: isScheduled,
            changedAt: changedAt ?? Date(),
            changedBy: changedBy ?? "",
            reason: reason ?? ""
        )
    }

    func update(from domain: ExamSlotHistory) {
        self.id = domain.id
        self.examSlotId = domain.examSlotId
        self.studentId = domain.studentId
        self.sectionId = domain.sectionId
        self.examNumber = Int16(domain.examNumber)
        self.weekNumber = Int16(domain.weekNumber)
        self.date = domain.date
        self.startTime = domain.startTime
        self.endTime = domain.endTime
        self.isScheduled = domain.isScheduled
        self.changedAt = domain.changedAt
        self.changedBy = domain.changedBy
        self.reason = domain.reason
    }

    static func create(from domain: ExamSlotHistory, in context: NSManagedObjectContext) -> ExamSlotHistoryEntity {
        let entity = ExamSlotHistoryEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
