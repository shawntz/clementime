//
//  PermissionChecker.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct PermissionChecker {
    let currentUser: TAUser
    let course: Course

    func can(_ action: PermissionType) -> Bool {
        // Admins have all permissions
        if currentUser.role == .admin {
            return true
        }

        // Course creator always has admin permissions
        if currentUser.id == course.createdBy {
            return true
        }

        // Check custom permissions
        return currentUser.customPermissions
            .first(where: { $0.type == action })?
            .isGranted ?? false
    }

    func canViewSchedules() -> Bool {
        can(.viewSchedules)
    }

    func canEditSchedules() -> Bool {
        can(.editSchedules)
    }

    func canRecordExams() -> Bool {
        can(.recordExams)
    }

    func canManageStudents() -> Bool {
        can(.manageStudents)
    }

    func canManageConstraints() -> Bool {
        can(.manageConstraints)
    }

    func canExportData() -> Bool {
        can(.exportData)
    }

    func canManageSettings() -> Bool {
        can(.manageSettings)
    }

    func canInviteCollaborators() -> Bool {
        can(.inviteCollaborators)
    }
}
