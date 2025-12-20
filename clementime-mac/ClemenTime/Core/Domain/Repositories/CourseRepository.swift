//
//  CourseRepository.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

protocol CourseRepository {
    /// Fetch all courses (both owned and shared)
    func fetchCourses() async throws -> [Course]

    /// Fetch a specific course by ID
    func fetchCourse(id: UUID) async throws -> Course?

    /// Create a new course
    func createCourse(_ course: Course) async throws -> Course

    /// Update an existing course
    func updateCourse(_ course: Course) async throws

    /// Delete a course
    func deleteCourse(id: UUID) async throws

    /// Share a course with another user via CloudKit
    func shareCourse(_ courseId: UUID, with email: String, permissions: [Permission]) async throws -> URL

    /// Accept a course share invitation
    func acceptShare(metadata: Any) async throws
}
