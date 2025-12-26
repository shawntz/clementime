//
//  ExamSessionRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

protocol ExamSessionRepository {
    /// Fetch all exam sessions for a course
    func fetchExamSessions(courseId: UUID) async throws -> [ExamSession]

    /// Fetch exam sessions for a specific exam number
    func fetchExamSession(courseId: UUID, examNumber: Int) async throws -> ExamSession?

    /// Fetch a specific exam session by ID
    func fetchExamSession(id: UUID) async throws -> ExamSession?

    /// Create a new exam session
    func createExamSession(_ session: ExamSession) async throws -> ExamSession

    /// Update an existing exam session
    func updateExamSession(_ session: ExamSession) async throws

    /// Delete an exam session
    func deleteExamSession(id: UUID) async throws
}
