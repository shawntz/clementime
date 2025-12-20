//
//  CohortRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

protocol CohortRepository {
    /// Fetch all cohorts for a course
    func fetchCohorts(courseId: UUID) async throws -> [Cohort]

    /// Fetch a specific cohort by ID
    func fetchCohort(id: UUID) async throws -> Cohort?

    /// Create a new cohort
    func createCohort(_ cohort: Cohort) async throws -> Cohort

    /// Update an existing cohort
    func updateCohort(_ cohort: Cohort) async throws

    /// Delete a cohort
    func deleteCohort(id: UUID) async throws

    /// Reorder cohorts
    func reorderCohorts(_ cohorts: [Cohort]) async throws
}
