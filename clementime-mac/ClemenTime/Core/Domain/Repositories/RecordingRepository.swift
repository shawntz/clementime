//
//  RecordingRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

protocol RecordingRepository {
    /// Fetch all recordings for a course
    func fetchRecordings(courseId: UUID) async throws -> [Recording]

    /// Fetch recordings for a specific student
    func fetchRecordings(studentId: UUID) async throws -> [Recording]

    /// Fetch recording for a specific exam slot
    func fetchRecording(examSlotId: UUID) async throws -> Recording?

    /// Fetch a specific recording by ID
    func fetchRecording(id: UUID) async throws -> Recording?

    /// Create a new recording with audio data
    func createRecording(_ recording: Recording, audioData: Data) async throws -> Recording

    /// Update an existing recording
    func updateRecording(_ recording: Recording) async throws

    /// Delete a recording
    func deleteRecording(id: UUID) async throws

    /// Upload recording to iCloud
    func uploadToiCloud(_ recordingId: UUID) async throws

    /// Download recording from iCloud
    func downloadFromiCloud(_ recordingId: UUID) async throws -> URL
}
