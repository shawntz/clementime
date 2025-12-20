//
//  ExamSlotEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension ExamSlotEntity {
    func toDomain() -> ExamSlot {
        ExamSlot(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            studentId: studentId ?? UUID(),
            sectionId: sectionId ?? UUID(),
            examSessionId: examSessionId ?? UUID(),
            date: date ?? Date(),
            startTime: startTime ?? Date(),
            endTime: endTime ?? Date(),
            isScheduled: isScheduled,
            isLocked: isLocked,
            notes: notes
        )
    }

    func update(from domain: ExamSlot) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.studentId = domain.studentId
        self.sectionId = domain.sectionId
        self.examSessionId = domain.examSessionId
        self.date = domain.date
        self.startTime = domain.startTime
        self.endTime = domain.endTime
        self.isScheduled = domain.isScheduled
        self.isLocked = domain.isLocked
        self.notes = domain.notes
    }

    static func create(from domain: ExamSlot, in context: NSManagedObjectContext) -> ExamSlotEntity {
        let entity = ExamSlotEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
