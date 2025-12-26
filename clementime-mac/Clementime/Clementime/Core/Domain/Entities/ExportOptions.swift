//
//  ExportOptions.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation

// MARK: - PDF Export Error

enum PDFExportError: LocalizedError {
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate PDF document"
        }
    }
}

// MARK: - PDF Layout Styles

enum PDFLayoutStyle: String, CaseIterable, Identifiable {
    case compact = "Compact"
    case detailed = "Detailed"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .compact:
            return "Minimal spacing, fits more content per page"
        case .detailed:
            return "Standard layout with all information"
        }
    }
}

// MARK: - Roster Export Options

struct RosterExportOptions {
    var layoutStyle: PDFLayoutStyle = .detailed
    var filterBySection: UUID? = nil
    var filterByCohort: UUID? = nil
    var includeEmail: Bool = true
    var includeSection: Bool = true
    var includeCohort: Bool = true
    var includeExamSlot: Bool = true
    var sortBy: RosterSortOption = .name

    enum RosterSortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case email = "Email"
        case section = "Section"

        var id: String { rawValue }
    }

    func sortedStudents(_ students: [Student]) -> [Student] {
        switch sortBy {
        case .name:
            return students.sorted { $0.fullName < $1.fullName }
        case .email:
            return students.sorted { $0.email < $1.email }
        case .section:
            return students.sorted { $0.sectionId.uuidString < $1.sectionId.uuidString }
        }
    }

    func shouldInclude(_ student: Student, cohorts: [Cohort] = []) -> Bool {
        // Filter by section
        if let sectionId = filterBySection {
            if student.sectionId != sectionId { return false }
        }

        // Filter by cohort
        if let cohortId = filterByCohort {
            // Use the new logic that includes "All Students" cohort
            if !student.belongsToCohortId(cohortId, allCohorts: cohorts) { return false }
        }

        return true
    }
}

// MARK: - Schedule Export Options

struct ScheduleExportOptions {
    var layoutStyle: PDFLayoutStyle = .detailed
    var filterBySection: UUID? = nil
    var filterByStatus: ScheduleStatusFilter = .all
    var filterByLocked: LockedFilter = .all
    var includeLogo: Bool = true
    var includeStatistics: Bool = true
    var includeNotes: Bool = true
    var groupByDate: Bool = true

    enum ScheduleStatusFilter: String, CaseIterable, Identifiable {
        case all = "All Slots"
        case scheduledOnly = "Scheduled Only"
        case unscheduledOnly = "Unscheduled Only"

        var id: String { rawValue }
    }

    enum LockedFilter: String, CaseIterable, Identifiable {
        case all = "All Slots"
        case lockedOnly = "Locked Only"
        case unlockedOnly = "Unlocked Only"

        var id: String { rawValue }
    }

    func shouldInclude(_ slot: ExamSlot) -> Bool {
        // Filter by status
        switch filterByStatus {
        case .all:
            break
        case .scheduledOnly:
            if !slot.isScheduled { return false }
        case .unscheduledOnly:
            if slot.isScheduled { return false }
        }

        // Filter by locked status
        switch filterByLocked {
        case .all:
            break
        case .lockedOnly:
            if !slot.isLocked { return false }
        case .unlockedOnly:
            if slot.isLocked { return false }
        }

        // Filter by section
        if let sectionId = filterBySection {
            if slot.sectionId != sectionId { return false }
        }

        return true
    }
}

// MARK: - TA List Export Options

struct TAListExportOptions {
    var layoutStyle: PDFLayoutStyle = .detailed
    var filterByRole: UserRole? = nil
    var includeLogo: Bool = true
    var includePermissions: Bool = true
    var includeContactInfo: Bool = true
    var sortBy: TASortOption = .name

    enum TASortOption: String, CaseIterable, Identifiable {
        case name = "Name"
        case role = "Role"
        case email = "Email"

        var id: String { rawValue }
    }

    func sortedTAUsers(_ users: [TAUser]) -> [TAUser] {
        switch sortBy {
        case .name:
            return users.sorted { $0.fullName < $1.fullName }
        case .role:
            return users.sorted { $0.role.rawValue < $1.role.rawValue }
        case .email:
            return users.sorted { $0.email < $1.email }
        }
    }

    func shouldInclude(_ user: TAUser) -> Bool {
        // Filter by role
        if let role = filterByRole {
            if user.role != role { return false }
        }

        return user.isActive
    }
}
