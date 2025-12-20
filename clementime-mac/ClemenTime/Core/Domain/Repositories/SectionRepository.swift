//
//  SectionRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

protocol SectionRepository {
    /// Fetch all sections for a course
    func fetchSections(courseId: UUID) async throws -> [Section]

    /// Fetch sections for a specific cohort
    func fetchSections(cohortId: UUID) async throws -> [Section]

    /// Fetch a specific section by ID
    func fetchSection(id: UUID) async throws -> Section?

    /// Create a new section
    func createSection(_ section: Section) async throws -> Section

    /// Update an existing section
    func updateSection(_ section: Section) async throws

    /// Delete a section
    func deleteSection(id: UUID) async throws

    /// Assign a TA to a section
    func assignTA(taUserId: UUID, toSectionId: UUID) async throws

    /// Unassign a TA from a section
    func unassignTA(fromSectionId: UUID) async throws
}
