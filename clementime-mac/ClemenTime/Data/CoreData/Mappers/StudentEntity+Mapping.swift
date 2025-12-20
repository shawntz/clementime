//
//  StudentEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension StudentEntity {
    func toDomain() -> Student {
        Student(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            sectionId: sectionId ?? UUID(),
            sisUserId: sisUserId ?? "",
            email: email ?? "",
            fullName: fullName ?? "",
            cohortId: cohortId ?? UUID(),
            slackUserId: slackUserId,
            slackUsername: slackUsername,
            isActive: isActive
        )
    }

    func update(from domain: Student) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.sectionId = domain.sectionId
        self.sisUserId = domain.sisUserId
        self.email = domain.email
        self.fullName = domain.fullName
        self.cohortId = domain.cohortId
        self.slackUserId = domain.slackUserId
        self.slackUsername = domain.slackUsername
        self.isActive = domain.isActive
    }

    static func create(from domain: Student, in context: NSManagedObjectContext) -> StudentEntity {
        let entity = StudentEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
