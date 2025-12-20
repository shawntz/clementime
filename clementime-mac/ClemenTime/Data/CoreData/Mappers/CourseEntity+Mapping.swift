//
//  CourseEntity+Mapping.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import CoreData

extension CourseEntity {
    /// Convert Core Data entity to domain model
    func toDomain() -> Course {
        // Decode metadata from JSON
        var metadata: [String: String] = [:]
        if let metadataJSON = metadataJSON, let data = metadataJSON.data(using: .utf8) {
            metadata = (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }

        return Course(
            id: id ?? UUID(),
            name: name ?? "",
            term: term ?? "",
            quarterStartDate: quarterStartDate ?? Date(),
            examDay: DayOfWeek(rawValue: examDay ?? "friday") ?? .friday,
            totalExams: Int(totalExams),
            isActive: isActive,
            createdBy: createdByUserId ?? UUID(),
            settings: CourseSettings.decode(from: settingsJSON ?? "{}"),
            metadata: metadata
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

        // Encode metadata to JSON
        if let data = try? JSONEncoder().encode(domain.metadata),
           let json = String(data: data, encoding: .utf8) {
            self.metadataJSON = json
        } else {
            self.metadataJSON = "{}"
        }
    }

    /// Create new Core Data entity from domain model
    static func create(from domain: Course, in context: NSManagedObjectContext) -> CourseEntity {
        let entity = CourseEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
