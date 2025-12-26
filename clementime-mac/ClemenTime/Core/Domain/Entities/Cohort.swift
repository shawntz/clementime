//
//  Cohort.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import SwiftUI

struct Cohort: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var isDefault: Bool // True for "All Students" cohort

    init(
        id: UUID = UUID(),
        courseId: UUID,
        name: String,
        colorHex: String = "#3B82F6", // Default blue
        sortOrder: Int = 0,
        isDefault: Bool = false
    ) {
        self.id = id
        self.courseId = courseId
        self.name = name
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.isDefault = isDefault
    }

    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    // Helper to create the default "All Students" cohort
    static func createAllStudentsCohort(courseId: UUID) -> Cohort {
        Cohort(
            id: UUID(),
            courseId: courseId,
            name: "All Students",
            colorHex: "#6B7280", // Gray color for "All Students"
            sortOrder: -1, // Always first
            isDefault: true
        )
    }
}
