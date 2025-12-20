//
//  RemoveCollaboratorUseCase.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct RemoveCollaboratorInput {
    let courseId: UUID
    let taUserId: UUID
    let currentUserId: UUID // For permission checking
}

class RemoveCollaboratorUseCase {
    private let courseRepository: CourseRepository
    private let taUserRepository: TAUserRepository
    private let shareManager: CloudKitShareManager

    init(
        courseRepository: CourseRepository,
        taUserRepository: TAUserRepository,
        shareManager: CloudKitShareManager
    ) {
        self.courseRepository = courseRepository
        self.taUserRepository = taUserRepository
        self.shareManager = shareManager
    }

    func execute(input: RemoveCollaboratorInput) async throws {
        // 1. Validate course exists
        guard let course = try await courseRepository.fetchCourse(id: input.courseId) else {
            throw UseCaseError.courseNotFound
        }

        // 2. Check permissions - only course creator can remove collaborators
        guard course.createdBy == input.currentUserId else {
            throw UseCaseError.permissionDenied
        }

        // 3. Fetch TA user to get email
        guard let taUser = try await taUserRepository.fetchTAUser(id: input.taUserId) else {
            throw UseCaseError.invalidInput
        }

        // 4. Remove from CloudKit share
        try await shareManager.removeParticipant(email: taUser.email, from: input.courseId)

        // Note: The TAUser entity will be deleted automatically via cascade delete
        // when the share is removed, or it's already deleted by shareManager.removeParticipant
    }
}
