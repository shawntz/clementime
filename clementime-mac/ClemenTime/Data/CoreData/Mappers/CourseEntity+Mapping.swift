//
//  CourseEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension CourseEntity {
    /// Convert Core Data entity to domain model
    func toDomain() -> Course {
        Course(
            id: id ?? UUID(),
            name: name ?? "",
            term: term ?? "",
            quarterStartDate: quarterStartDate ?? Date(),
            examDay: DayOfWeek(rawValue: examDay ?? "friday") ?? .friday,
            totalExams: Int(totalExams),
            isActive: isActive,
            createdBy: createdByUserId ?? UUID(),
            settings: CourseSettings.decode(from: settingsJSON ?? "{}")
        )
    }

    /// Update Core Data entity from domain model
    func update(from domain: Course) {
        self.id = domain.id
        self.name = domain.name
        self.term = domain.term
        self.quarterStartDate = domain.quarterStartDate
        self.examDay = domain.examDay.rawValue
        self.totalExams = Int16(domain.totalExams)
        self.isActive = domain.isActive
        self.createdByUserId = domain.createdBy
        self.settingsJSON = domain.settings.encode()
    }

    /// Create new Core Data entity from domain model
    static func create(from domain: Course, in context: NSManagedObjectContext) -> CourseEntity {
        let entity = CourseEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
