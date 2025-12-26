//
//  TAUser.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct TAUser: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var firstName: String
    var lastName: String
    var email: String
    var username: String
    var role: UserRole
    var customPermissions: [Permission]
    var location: String
    var slackId: String?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        courseId: UUID,
        firstName: String,
        lastName: String,
        email: String,
        username: String,
        role: UserRole,
        customPermissions: [Permission] = [],
        location: String = "",
        slackId: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.courseId = courseId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.username = username
        self.role = role
        self.customPermissions = customPermissions.isEmpty && role == .admin ? Permission.allPermissions() : customPermissions
        self.location = location
        self.slackId = slackId
        self.isActive = isActive
    }

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var hasSlackConnection: Bool {
        slackId != nil
    }

    func hasPermission(_ type: PermissionType) -> Bool {
        // Admins always have all permissions
        if role == .admin {
            return true
        }

        // Check custom permissions
        return customPermissions.first(where: { $0.type == type })?.isGranted ?? false
    }

    // Encode permissions to JSON string for Core Data storage
    func permissionsToJSON() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(customPermissions),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    // Decode permissions from JSON string
    static func permissionsFromJSON(_ json: String) -> [Permission] {
        let decoder = JSONDecoder()
        guard let data = json.data(using: .utf8),
              let permissions = try? decoder.decode([Permission].self, from: data) else {
            return []
        }
        return permissions
    }
}

// MARK: - User Role

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case admin
    case ta

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .admin:
            return "Admin"
        case .ta:
            return "Teaching Assistant"
        }
    }
}

// MARK: - Permission

struct Permission: Codable, Hashable, Identifiable {
    var id: String { type.rawValue }
    var type: PermissionType
    var isGranted: Bool

    init(type: PermissionType, isGranted: Bool = false) {
        self.type = type
        self.isGranted = isGranted
    }

    static func allPermissions() -> [Permission] {
        PermissionType.allCases.map { Permission(type: $0, isGranted: true) }
    }

    static func defaultTAPermissions() -> [Permission] {
        [
            Permission(type: .viewSchedules, isGranted: true),
            Permission(type: .recordExams, isGranted: true),
            Permission(type: .editSchedules, isGranted: false),
            Permission(type: .manageStudents, isGranted: false),
            Permission(type: .manageConstraints, isGranted: false),
            Permission(type: .exportData, isGranted: false),
            Permission(type: .manageSettings, isGranted: false),
            Permission(type: .inviteCollaborators, isGranted: false)
        ]
    }
}

// MARK: - Permission Type

enum PermissionType: String, Codable, CaseIterable {
    case viewSchedules = "view_schedules"
    case editSchedules = "edit_schedules"
    case recordExams = "record_exams"
    case manageStudents = "manage_students"
    case manageConstraints = "manage_constraints"
    case exportData = "export_data"
    case manageSettings = "manage_settings"
    case inviteCollaborators = "invite_collaborators"

    var displayName: String {
        switch self {
        case .viewSchedules:
            return "View Schedules"
        case .editSchedules:
            return "Edit Schedules"
        case .recordExams:
            return "Record Exams"
        case .manageStudents:
            return "Manage Students"
        case .manageConstraints:
            return "Manage Constraints"
        case .exportData:
            return "Export Data"
        case .manageSettings:
            return "Manage Settings"
        case .inviteCollaborators:
            return "Invite Collaborators"
        }
    }

    var description: String {
        switch self {
        case .viewSchedules:
            return "View exam schedules and student information"
        case .editSchedules:
            return "Modify exam slots and regenerate schedules"
        case .recordExams:
            return "Record exams and upload recordings"
        case .manageStudents:
            return "Add, edit, and remove students"
        case .manageConstraints:
            return "Create and modify student scheduling constraints"
        case .exportData:
            return "Export schedules and student data to CSV"
        case .manageSettings:
            return "Modify course settings and configuration"
        case .inviteCollaborators:
            return "Invite and manage other TAs and admins"
        }
    }

    var icon: String {
        switch self {
        case .viewSchedules:
            return "calendar"
        case .editSchedules:
            return "calendar.badge.pencil"
        case .recordExams:
            return "waveform.circle"
        case .manageStudents:
            return "person.2"
        case .manageConstraints:
            return "slider.horizontal.3"
        case .exportData:
            return "square.and.arrow.up"
        case .manageSettings:
            return "gearshape"
        case .inviteCollaborators:
            return "person.badge.plus"
        }
    }
}
