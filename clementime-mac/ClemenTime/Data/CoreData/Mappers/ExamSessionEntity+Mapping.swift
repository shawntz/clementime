//
//  ExamSessionEntity+Mapping.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import CoreData

extension ExamSessionEntity {
    func toDomain() -> ExamSession {
        ExamSession(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            examNumber: Int(examNumber),
            weekStartDate: weekStartDate ?? Date(),
            assignedCohortId: assignedCohortId,
            theme: theme,
            durationMinutes: Int(durationMinutes),
            bufferMinutes: Int(bufferMinutes)
        )
    }

    func update(from domain: ExamSession) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.examNumber = Int16(domain.examNumber)
        self.weekStartDate = domain.weekStartDate
        self.assignedCohortId = domain.assignedCohortId
        self.theme = domain.theme
        self.durationMinutes = Int16(domain.durationMinutes)
        self.bufferMinutes = Int16(domain.bufferMinutes)
    }

    static func create(from domain: ExamSession, in context: NSManagedObjectContext) -> ExamSessionEntity {
        let entity = ExamSessionEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
