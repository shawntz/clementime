//
//  Student.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct Student: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var sectionId: UUID
    var sisUserId: String
    var email: String
    var fullName: String
    var cohortId: UUID
    var slackUserId: String?
    var slackUsername: String?
    var isActive: Bool
    var unmatchedSectionCode: String? // Section code from CSV that couldn't be matched

    // Related entities (loaded separately)
    var constraints: [Constraint] = []
    var examSlots: [ExamSlot] = []

    init(
        id: UUID = UUID(),
        courseId: UUID,
        sectionId: UUID,
        sisUserId: String,
        email: String,
        fullName: String,
        cohortId: UUID,
        slackUserId: String? = nil,
        slackUsername: String? = nil,
        isActive: Bool = true,
        unmatchedSectionCode: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.sectionId = sectionId
        self.sisUserId = sisUserId
        self.email = email
        self.fullName = fullName
        self.cohortId = cohortId
        self.slackUserId = slackUserId
        self.slackUsername = slackUsername
        self.isActive = isActive
        self.unmatchedSectionCode = unmatchedSectionCode
    }

    // Computed properties
    var scheduledExamsCount: Int {
        examSlots.filter { $0.isScheduled }.count
    }

    var hasConstraints: Bool {
        !constraints.filter { $0.isActive }.isEmpty
    }

    var activeConstraints: [Constraint] {
        constraints.filter { $0.isActive }
    }

    var hasSlackConnection: Bool {
        slackUserId != nil
    }

    // Computed property
    var hasUnmatchedSection: Bool {
        unmatchedSectionCode != nil
    }

    // Sort value for status (used for table sorting)
    var statusSortValue: String {
        isActive ? "A_Active" : "Z_Inactive"
    }

    // Check if student belongs to a specific cohort
    // All students implicitly belong to the "All Students" (default) cohort
    func belongsToCohort(_ cohort: Cohort) -> Bool {
        // All students belong to the default "All Students" cohort
        if cohort.isDefault {
            return true
        }
        // Otherwise check if it matches their assigned cohort
        return cohort.id == cohortId
    }

    func belongsToCohortId(_ cohortId: UUID, allCohorts: [Cohort]) -> Bool {
        // Check if this is the "All Students" cohort
        if let cohort = allCohorts.first(where: { $0.id == cohortId }), cohort.isDefault {
            return true
        }
        // Otherwise check if it matches their assigned cohort
        return self.cohortId == cohortId
    }

    // Coding keys for Codable conformance (exclude non-persisted fields)
    enum CodingKeys: String, CodingKey {
        case id, courseId, sectionId, sisUserId, email, fullName
        case cohortId, slackUserId, slackUsername, isActive, unmatchedSectionCode
    }
}

// MARK: - Import Result

struct ImportResult {
    var successCount: Int
    var failureCount: Int
    var errors: [ImportError]

    struct ImportError: Identifiable {
        let id = UUID()
        let row: Int
        let studentName: String?
        let reason: String
    }

    var totalCount: Int {
        successCount + failureCount
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }
}
