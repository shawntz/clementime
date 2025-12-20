//
//  ExamSessionEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension ExamSessionEntity {
    func toDomain() -> ExamSession {
        ExamSession(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            examNumber: Int(examNumber),
            oddWeekDate: oddWeekDate ?? Date(),
            evenWeekDate: evenWeekDate ?? Date(),
            theme: theme,
            startTime: startTime ?? "13:30",
            endTime: endTime ?? "14:50",
            durationMinutes: Int(durationMinutes),
            bufferMinutes: Int(bufferMinutes)
        )
    }

    func update(from domain: ExamSession) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.examNumber = Int16(domain.examNumber)
        self.oddWeekDate = domain.oddWeekDate
        self.evenWeekDate = domain.evenWeekDate
        self.theme = domain.theme
        self.startTime = domain.startTime
        self.endTime = domain.endTime
        self.durationMinutes = Int16(domain.durationMinutes)
        self.bufferMinutes = Int16(domain.bufferMinutes)
    }

    static func create(from domain: ExamSession, in context: NSManagedObjectContext) -> ExamSessionEntity {
        let entity = ExamSessionEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
