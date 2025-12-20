//
//  ShareCourseViewModel.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import Combine
import AppKit

@MainActor
class ShareCourseViewModel: ObservableObject {
    @Published var collaboratorEmail = ""
    @Published var collaboratorFirstName = ""
    @Published var collaboratorLastName = ""
    @Published var selectedRole: UserRole = .ta
    @Published var selectedPermissions: Set<PermissionType> = [
        .viewSchedules,
        .editSchedules,
        .recordExams
    ]

    @Published var collaborators: [TAUser] = []
    @Published var isSharing = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var successMessage: String?
    @Published var shareURL: URL?
    @Published var canInviteCollaborators = false

    private let course: Course
    private let shareCourseUseCase: ShareCourseUseCase
    private let removeCollaboratorUseCase: RemoveCollaboratorUseCase
    private let taUserRepository: TAUserRepository
    private let permissionChecker: PermissionChecker
    private let currentUserId: UUID

    init(
        course: Course,
        shareCourseUseCase: ShareCourseUseCase,
        removeCollaboratorUseCase: RemoveCollaboratorUseCase,
        taUserRepository: TAUserRepository,
        permissionChecker: PermissionChecker,
        currentUserId: UUID
    ) {
        self.course = course
        self.shareCourseUseCase = shareCourseUseCase
        self.removeCollaboratorUseCase = removeCollaboratorUseCase
        self.taUserRepository = taUserRepository
        self.permissionChecker = permissionChecker
        self.currentUserId = currentUserId

        self.canInviteCollaborators = permissionChecker.can(.inviteCollaborators)
    }

    func loadCollaborators() async {
        isLoading = true
        error = nil

        do {
            collaborators = try await taUserRepository.fetchTAUsers(courseId: course.id)
        } catch {
            self.error = "Failed to load collaborators: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func shareCourse() async {
        guard permissionChecker.can(.inviteCollaborators) else {
            error = "You don't have permission to invite collaborators"
            return
        }

        guard isValid else {
            error = "Please fill in all required fields"
            return
        }

        isSharing = true
        error = nil
        successMessage = nil
        shareURL = nil

        do {
            let input = ShareCourseInput(
                courseId: course.id,
                collaboratorEmail: collaboratorEmail,
                collaboratorFirstName: collaboratorFirstName,
                collaboratorLastName: collaboratorLastName,
                role: selectedRole,
                permissions: Array(selectedPermissions)
            )

            let output = try await shareCourseUseCase.execute(input: input)

            shareURL = output.shareURL
            successMessage = "Successfully invited \(output.taUser.fullName). Share URL copied to clipboard."

            // Copy URL to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(output.shareURL.absoluteString, forType: .string)

            // Reset form
            resetForm()

            // Reload collaborators
            await loadCollaborators()
        } catch {
            self.error = "Failed to share course: \(error.localizedDescription)"
        }

        isSharing = false
    }

    func removeCollaborator(_ taUser: TAUser) async {
        guard permissionChecker.can(.inviteCollaborators) else {
            error = "You don't have permission to remove collaborators"
            return
        }

        do {
            let input = RemoveCollaboratorInput(
                courseId: course.id,
                taUserId: taUser.id,
                currentUserId: currentUserId
            )

            try await removeCollaboratorUseCase.execute(input: input)
            successMessage = "Removed \(taUser.fullName) from course"
            await loadCollaborators()
        } catch {
            self.error = "Failed to remove collaborator: \(error.localizedDescription)"
        }
    }

    func togglePermission(_ permission: PermissionType) {
        if selectedPermissions.contains(permission) {
            selectedPermissions.remove(permission)
        } else {
            selectedPermissions.insert(permission)
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        !collaboratorEmail.isEmpty &&
        !collaboratorFirstName.isEmpty &&
        !collaboratorLastName.isEmpty &&
        isValidEmail(collaboratorEmail)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    private func resetForm() {
        collaboratorEmail = ""
        collaboratorFirstName = ""
        collaboratorLastName = ""
        selectedRole = .ta
        selectedPermissions = [.viewSchedules, .editSchedules, .recordExams]
    }

    // MARK: - Permission Descriptions

    func permissionDescription(_ permission: PermissionType) -> String {
        switch permission {
        case .viewSchedules:
            return "View exam schedules and student assignments"
        case .editSchedules:
            return "Modify exam slots, lock/unlock, and swap times"
        case .recordExams:
            return "Upload audio recordings for exams"
        case .manageStudents:
            return "Add, edit, and delete students"
        case .manageConstraints:
            return "Edit student scheduling constraints"
        case .exportData:
            return "Export schedules to CSV"
        case .manageSettings:
            return "Edit course settings and exam sessions"
        case .inviteCollaborators:
            return "Invite other TAs to the course"
        }
    }
}
