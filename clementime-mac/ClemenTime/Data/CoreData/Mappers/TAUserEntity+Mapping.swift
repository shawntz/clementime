//
//  TAUserEntity+Mapping.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import CoreData

extension TAUserEntity {
    func toDomain() -> TAUser {
        TAUser(
            id: id ?? UUID(),
            courseId: courseId ?? UUID(),
            firstName: firstName ?? "",
            lastName: lastName ?? "",
            email: email ?? "",
            username: username ?? "",
            role: UserRole(rawValue: role ?? "ta") ?? .ta,
            customPermissions: Permission.decode(from: permissionsJSON ?? "[]"),
            location: location ?? "",
            slackId: slackId,
            isActive: isActive
        )
    }

    func update(from domain: TAUser) {
        self.id = domain.id
        self.courseId = domain.courseId
        self.firstName = domain.firstName
        self.lastName = domain.lastName
        self.email = domain.email
        self.username = domain.username
        self.role = domain.role.rawValue
        self.permissionsJSON = Permission.encode(domain.customPermissions)
        self.location = domain.location
        self.slackId = domain.slackId
        self.isActive = domain.isActive
    }

    static func create(from domain: TAUser, in context: NSManagedObjectContext) -> TAUserEntity {
        let entity = TAUserEntity(context: context)
        entity.update(from: domain)
        return entity
    }
}

// MARK: - Permission JSON Encoding/Decoding
extension Permission {
    static func encode(_ permissions: [Permission]) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(permissions),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func decode(from json: String) -> [Permission] {
        let decoder = JSONDecoder()
        guard let data = json.data(using: .utf8),
              let permissions = try? decoder.decode([Permission].self, from: data) else {
            return []
        }
        return permissions
    }
}
