//
//  TAUserRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

protocol TAUserRepository {
    /// Fetch all TAs for a course
    func fetchTAUsers(courseId: UUID) async throws -> [TAUser]

    /// Fetch a specific TA by ID
    func fetchTAUser(id: UUID) async throws -> TAUser?

    /// Fetch a TA by email
    func fetchTAUser(email: String, courseId: UUID) async throws -> TAUser?

    /// Create a new TA user
    func createTAUser(_ taUser: TAUser) async throws -> TAUser

    /// Update an existing TA user
    func updateTAUser(_ taUser: TAUser) async throws

    /// Delete a TA user
    func deleteTAUser(id: UUID) async throws

    /// Update TA permissions
    func updatePermissions(taUserId: UUID, permissions: [Permission]) async throws
}
