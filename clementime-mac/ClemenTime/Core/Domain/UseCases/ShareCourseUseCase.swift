//
//  ShareCourseUseCase.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct ShareCourseInput {
    let courseId: UUID
    let collaboratorEmail: String
    let collaboratorFirstName: String
    let collaboratorLastName: String
    let role: UserRole
    let permissions: [PermissionType]
}

struct ShareCourseOutput {
    let shareURL: URL
    let taUser: TAUser
}

class ShareCourseUseCase {
    private let courseRepository: CourseRepository
    private let taUserRepository: TAUserRepository

    init(courseRepository: CourseRepository, taUserRepository: TAUserRepository) {
        self.courseRepository = courseRepository
        self.taUserRepository = taUserRepository
    }

    func execute(input: ShareCourseInput) async throws -> ShareCourseOutput {
        // 1. Validate course exists
        guard (try await courseRepository.fetchCourse(id: input.courseId)) != nil else {
            throw UseCaseError.courseNotFound
        }

        // 2. Check if user is already a collaborator
        if let existingTA = try await taUserRepository.fetchTAUser(
            email: input.collaboratorEmail,
            courseId: input.courseId
        ) {
            throw UseCaseError.collaboratorAlreadyExists(existingTA.fullName)
        }

        // 3. Convert permission types to Permission objects
        let permissions = input.permissions.map { permissionType in
            Permission(type: permissionType, isGranted: true)
        }

        // 4. Share course via CloudKit
        let shareURL = try await courseRepository.shareCourse(
            input.courseId,
            with: input.collaboratorEmail,
            permissions: permissions
        )

        // 5. Fetch the created TA user
        guard let taUser = try await taUserRepository.fetchTAUser(
            email: input.collaboratorEmail,
            courseId: input.courseId
        ) else {
            throw UseCaseError.taUserCreationFailed
        }

        return ShareCourseOutput(shareURL: shareURL, taUser: taUser)
    }
}

// MARK: - Use Case Errors
enum UseCaseError: Error, LocalizedError {
    case courseNotFound
    case collaboratorAlreadyExists(String)
    case taUserCreationFailed
    case permissionDenied
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .courseNotFound:
            return "Course not found."
        case .collaboratorAlreadyExists(let name):
            return "\(name) is already a collaborator on this course."
        case .taUserCreationFailed:
            return "Failed to create TA user record."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .invalidInput:
            return "Invalid input provided."
        }
    }
}
