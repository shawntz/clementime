//
//  SectionEntity+Mapping.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import CoreData

extension SectionEntity {
    func toDomain() -> Section {
        Section(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            code: code ?? "",
            name: name ?? "",
            location: location ?? "",
            assignedTAId: assignedTAId,
            weekday: Int(weekday),
            startTime: startTime ?? "13:30",
            endTime: endTime ?? "14:50",
            isActive: isActive,
            shouldIgnoreForMatching: shouldIgnoreForMatching
        )
    }

    func update(from domain: Section) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.code = domain.code
        self.name = domain.name
        self.location = domain.location
        self.assignedTAId = domain.assignedTAId
        self.weekday = Int16(domain.weekday)
        self.startTime = domain.startTime
        self.endTime = domain.endTime
        self.isActive = domain.isActive
        self.shouldIgnoreForMatching = domain.shouldIgnoreForMatching
    }

    static func create(from domain: Section, in context: NSManagedObjectContext) -> SectionEntity {
        let entity = SectionEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
