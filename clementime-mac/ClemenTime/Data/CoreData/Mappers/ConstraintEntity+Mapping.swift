//
//  ConstraintEntity+Mapping.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CoreData

extension ConstraintEntity {
    func toDomain() -> Constraint {
        Constraint(
            id: id ?? UUID(),
            studentId: studentId ?? UUID(),
            constraintType: ConstraintType(rawValue: constraintType ?? "") ?? .timeBefore,
            constraintValue: constraintValue ?? "",
            constraintDescription: constraintDescription ?? "",
            isActive: isActive
        )
    }

    func update(from domain: Constraint) {
        self.id = domain.id
        self.studentId = domain.studentId
        self.constraintType = domain.constraintType.rawValue
        self.constraintValue = domain.constraintValue
        self.constraintDescription = domain.constraintDescription
        self.isActive = domain.isActive
    }

    static func create(from domain: Constraint, in context: NSManagedObjectContext) -> ConstraintEntity {
        let entity = ConstraintEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}
