//
//  ConstraintRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

protocol ConstraintRepository {
    /// Fetch all constraints for a student
    func fetchConstraints(studentId: UUID) async throws -> [Constraint]

    /// Fetch active constraints for a student
    func fetchActiveConstraints(studentId: UUID) async throws -> [Constraint]

    /// Fetch a specific constraint by ID
    func fetchConstraint(id: UUID) async throws -> Constraint?

    /// Create a new constraint
    func createConstraint(_ constraint: Constraint) async throws -> Constraint

    /// Update an existing constraint
    func updateConstraint(_ constraint: Constraint) async throws

    /// Delete a constraint
    func deleteConstraint(id: UUID) async throws

    /// Toggle constraint active status
    func toggleConstraint(id: UUID) async throws
}
