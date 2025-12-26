//
//  CourseExport.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation

// MARK: - Course Export Container

struct CourseExport: Codable {
    let version: String // Export format version
    let exportedAt: Date
    let course: CourseExportData
    let cohorts: [CohortExportData]
    let sections: [SectionExportData]
    let students: [StudentExportData]
    let examSessions: [ExamSessionExportData]
    let examSlots: [ExamSlotExportData]
    let constraints: [ConstraintExportData]
    let taUsers: [TAUserExportData]

    static let currentVersion = "1.0"
}

// MARK: - Export Data Models

struct CourseExportData: Codable {
    let name: String
    let term: String
    let quarterStartDate: Date
    let quarterEndDate: Date
    let totalExams: Int
    let isActive: Bool
    let settingsJSON: String
    let metadataJSON: String?
}

struct CohortExportData: Codable {
    let id: UUID
    let name: String
    let colorHex: String
    let sortOrder: Int
    let isDefault: Bool
}

struct SectionExportData: Codable {
    let id: UUID
    let code: String
    let name: String
    let location: String
    let assignedTAId: UUID?
    let weekday: Int
    let startTime: String
    let endTime: String
    let isActive: Bool
}

struct StudentExportData: Codable {
    let id: UUID
    let sectionId: UUID
    let cohortId: UUID
    let sisUserId: String
    let email: String
    let fullName: String
    let slackUserId: String?
    let slackUsername: String?
    let isActive: Bool
}

struct ExamSessionExportData: Codable {
    let id: UUID
    let examNumber: Int
    let weekStartDate: Date
    let assignedCohortId: UUID?
    let theme: String?
    let durationMinutes: Int
    let bufferMinutes: Int
}

struct ExamSlotExportData: Codable {
    let id: UUID
    let studentId: UUID
    let sectionId: UUID
    let examSessionId: UUID
    let date: Date
    let startTime: Date
    let endTime: Date
    let isScheduled: Bool
    let isLocked: Bool
    let notes: String?
}

struct ConstraintExportData: Codable {
    let id: UUID
    let studentId: UUID
    let type: String
    let value: String
    let description: String
    let isActive: Bool
}

struct TAUserExportData: Codable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String
    let username: String
    let role: String
    let permissionsJSON: String
    let location: String
    let slackId: String?
    let isActive: Bool
}

// MARK: - Import Result

struct CourseImportResult {
    var success: Bool
    var importedCourseId: UUID?
    var errors: [String]
    var warnings: [String]

    var studentsImported: Int = 0
    var sectionsImported: Int = 0
    var cohortsImported: Int = 0
    var examSessionsImported: Int = 0
    var examSlotsImported: Int = 0
    var constraintsImported: Int = 0
    var taUsersImported: Int = 0
}
