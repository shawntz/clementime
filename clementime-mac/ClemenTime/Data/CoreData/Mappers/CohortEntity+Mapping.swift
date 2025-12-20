//
//  CohortEntity+Mapping.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import CoreData

extension CohortEntity {
    func toDomain() -> Cohort {
        Cohort(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            name: name ?? "",
            weekType: WeekType(rawValue: weekType ?? "odd") ?? .odd,
            colorHex: colorHex ?? "#007AFF",
            sortOrder: Int(sortOrder)
        )
    }

    func update(from domain: Cohort) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.name = domain.name
        self.weekType = domain.weekType.rawValue
        self.colorHex = domain.colorHex
        self.sortOrder = Int16(domain.sortOrder)
    }

    static func create(from domain: Cohort, in context: NSManagedObjectContext) -> CohortEntity {
        let entity = CohortEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
