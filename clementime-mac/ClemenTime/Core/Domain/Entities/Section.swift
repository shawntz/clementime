//
//  Section.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct Section: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var code: String
    var name: String
    var location: String
    var assignedTAId: UUID?
    var cohortId: UUID
    var isActive: Bool

    init(
        id: UUID = UUID(),
        courseId: UUID,
        code: String,
        name: String,
        location: String = "",
        assignedTAId: UUID? = nil,
        cohortId: UUID,
        isActive: Bool = true
    ) {
        self.id = id
        self.courseId = courseId
        self.code = code
        self.name = name
        self.location = location
        self.assignedTAId = assignedTAId
        self.cohortId = cohortId
        self.isActive = isActive
    }

    var displayName: String {
        "\(code) - \(name)"
    }

    var hasAssignedTA: Bool {
        assignedTAId != nil
    }
}
