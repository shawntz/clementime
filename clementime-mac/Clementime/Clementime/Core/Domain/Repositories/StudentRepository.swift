//
//  StudentRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

protocol StudentRepository {
    /// Fetch all students for a course
    func fetchStudents(courseId: UUID) async throws -> [Student]

    /// Fetch students for a specific section
    func fetchStudents(sectionId: UUID) async throws -> [Student]

    /// Fetch a specific student by ID
    func fetchStudent(id: UUID) async throws -> Student?

    /// Fetch a student by SIS user ID
    func fetchStudent(sisUserId: String, courseId: UUID) async throws -> Student?

    /// Create a new student
    func createStudent(_ student: Student) async throws -> Student

    /// Update an existing student
    func updateStudent(_ student: Student) async throws

    /// Delete a student
    func deleteStudent(id: UUID) async throws

    /// Delete all students for a course
    func deleteAllStudents(courseId: UUID) async throws

    /// Import students from CSV
    func importStudents(from csvURL: URL, courseId: UUID, randomlyAssignCohorts: Bool) async throws -> ImportResult

    /// Randomly reassign all students to cohorts with even distribution
    func randomlyReassignCohorts(courseId: UUID) async throws -> Int

    /// Fix students with invalid cohort assignments (All Students or placeholder IDs)
    func fixInvalidCohortAssignments(courseId: UUID) async throws -> Int
}
