//
//  AcceptShareUseCase.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import CloudKit

struct AcceptShareInput {
    let shareMetadata: CKShare.Metadata
}

struct AcceptShareOutput {
    let course: Course
    let myRole: UserRole
}

class AcceptShareUseCase {
    private let courseRepository: CourseRepository
    private let taUserRepository: TAUserRepository

    init(courseRepository: CourseRepository, taUserRepository: TAUserRepository) {
        self.courseRepository = courseRepository
        self.taUserRepository = taUserRepository
    }

    func execute(input: AcceptShareInput) async throws -> AcceptShareOutput {
        // 1. Accept the share via CloudKit
        try await courseRepository.acceptShare(metadata: input.shareMetadata)

        // 2. Extract course ID from share
        let rootRecord = input.shareMetadata.rootRecord
        let courseId = UUID(uuidString: rootRecord.recordID.recordName) ?? UUID()

        // 3. Wait for course to sync to Core Data
        // Try fetching with a brief delay to allow sync
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        guard let course = try await courseRepository.fetchCourse(id: courseId) else {
            throw UseCaseError.courseNotFound
        }

        // 4. Get current user's email from share metadata
        // For now, we'll need to get this from CloudKit's user identity
        guard let participantEmail = getCurrentUserEmail() else {
            throw UseCaseError.invalidInput
        }

        // 5. Fetch TA user record to get permissions
        guard let taUser = try await taUserRepository.fetchTAUser(
            email: participantEmail,
            courseId: courseId
        ) else {
            throw UseCaseError.taUserCreationFailed
        }

        return AcceptShareOutput(course: course, myRole: taUser.role)
    }

    // MARK: - Helper Methods

    private func getCurrentUserEmail() -> String? {
        // This would typically come from CloudKit's user identity
        // For now, return nil - will be implemented when integrating with CloudKit user identity
        return nil
    }
}
