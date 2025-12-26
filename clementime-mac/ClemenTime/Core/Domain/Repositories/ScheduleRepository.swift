//
//  ScheduleRepository.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

protocol ScheduleRepository {
    /// Fetch all exam slots for a course
    func fetchExamSlots(courseId: UUID) async throws -> [ExamSlot]

    /// Fetch exam slots for a specific exam number
    func fetchExamSlots(courseId: UUID, examNumber: Int) async throws -> [ExamSlot]

    /// Fetch exam slots for a specific student
    func fetchExamSlots(studentId: UUID) async throws -> [ExamSlot]

    /// Fetch a specific exam slot by ID
    func fetchExamSlot(id: UUID) async throws -> ExamSlot?

    /// Generate schedule for all exams or starting from a specific exam
    func generateSchedule(courseId: UUID, startingFromExam: Int?) async throws -> ScheduleResult

    /// Update an existing exam slot
    func updateExamSlot(_ slot: ExamSlot) async throws

    /// Lock an exam slot to prevent changes during regeneration
    func lockExamSlot(id: UUID) async throws

    /// Unlock an exam slot
    func unlockExamSlot(id: UUID) async throws

    /// Swap two exam slots
    func swapExamSlots(slot1Id: UUID, slot2Id: UUID) async throws

    /// Fetch exam slot history for a student
    func fetchExamSlotHistory(studentId: UUID) async throws -> [ExamSlotHistory]

    /// Fetch exam slot history for a specific exam slot
    func fetchExamSlotHistory(examSlotId: UUID) async throws -> [ExamSlotHistory]

    /// Delete all unlocked exam slots for a specific exam session
    func deleteUnlockedExamSlots(examSessionId: UUID) async throws

    /// Delete all unlocked exam slots for a specific exam number in a course
    func deleteUnlockedExamSlots(courseId: UUID, examNumber: Int) async throws
}
