//
//  CourseBuilderViewModel.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class CourseBuilderViewModel: ObservableObject {
    // Course info
    @Published var courseName = ""
    @Published var term = ""
    @Published var quarterStartDate = Date()
    @Published var quarterEndDate = Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date() // Default to ~10 weeks
    @Published var totalExams = 5

    // Cohorts
    @Published var cohorts: [CohortBuilder] = []

    // Exam sessions
    @Published var examSessions: [ExamSessionBuilder] = []

    // State
    @Published var isCreating = false
    @Published var error: String?

    private let createCourseUseCase: CreateCourseUseCase
    private let currentUserId: UUID

    init(createCourseUseCase: CreateCourseUseCase, currentUserId: UUID) {
        self.createCourseUseCase = createCourseUseCase
        self.currentUserId = currentUserId

        // Add default cohorts
        addDefaultCohorts()

        // Add default exam sessions
        generateExamSessions()
    }

    // MARK: - Actions

    func addCohort() {
        let sortOrder = cohorts.count
        let cohort = CohortBuilder(
            id: UUID(),
            name: "",
            colorHex: randomColor(),
            sortOrder: sortOrder,
            isDefault: false
        )
        cohorts.append(cohort)
    }

    func deleteCohort(at index: Int) {
        cohorts.remove(at: index)
        // Reorder remaining cohorts
        for (idx, _) in cohorts.enumerated() {
            cohorts[idx].sortOrder = idx
        }
    }

    func addDefaultCohorts() {
        cohorts = [
            CohortBuilder(id: UUID(), name: "All Students", colorHex: "#6B7280", sortOrder: -1, isDefault: true),
            CohortBuilder(id: UUID(), name: "A", colorHex: "#007AFF", sortOrder: 0, isDefault: false),
            CohortBuilder(id: UUID(), name: "B", colorHex: "#34C759", sortOrder: 1, isDefault: false)
        ]
    }

    func generateExamSessions() {
        examSessions.removeAll()

        let calendar = Calendar.current
        var currentWeekStart = quarterStartDate

        // Find first Monday (start of week)
        while currentWeekStart.weekdayNumber != 2 { // 2 = Monday
            currentWeekStart = calendar.date(byAdding: .day, value: -1, to: currentWeekStart) ?? currentWeekStart
        }

        for examNumber in 1...totalExams {
            let session = ExamSessionBuilder(
                id: UUID(),
                examNumber: examNumber,
                weekStartDate: currentWeekStart,
                assignedCohortId: nil, // Default to "All Students"
                theme: nil,
                durationMinutes: 7, // Default duration
                bufferMinutes: 1 // Default buffer
            )
            examSessions.append(session)

            // Advance by 1 week
            currentWeekStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) ?? currentWeekStart
        }
    }

    func createCourse() async -> Course? {
        guard isValid else {
            error = "Please fill in all required fields"
            return nil
        }

        isCreating = true
        error = nil

        do {
            let settings = CourseSettings(
                balancedTAScheduling: false
            )

            let input = CreateCourseInput(
                name: courseName,
                term: term,
                quarterStartDate: quarterStartDate,
                quarterEndDate: quarterEndDate,
                totalExams: totalExams,
                cohorts: cohorts.map { CohortInput(
                    name: $0.name,
                    colorHex: $0.colorHex,
                    sortOrder: $0.sortOrder,
                    isDefault: $0.isDefault
                )},
                examSessions: examSessions.map { ExamSessionInput(
                    examNumber: $0.examNumber,
                    weekStartDate: $0.weekStartDate,
                    assignedCohortId: $0.assignedCohortId,
                    theme: $0.theme,
                    durationMinutes: $0.durationMinutes,
                    bufferMinutes: $0.bufferMinutes
                )},
                settings: settings,
                createdBy: currentUserId
            )

            let output = try await createCourseUseCase.execute(input: input)
            isCreating = false
            return output.course
        } catch {
            self.error = "Failed to create course: \(error.localizedDescription)"
            isCreating = false
            return nil
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        !courseName.isEmpty &&
        !term.isEmpty &&
        !cohorts.isEmpty &&
        cohorts.allSatisfy { !$0.name.isEmpty } &&
        totalExams > 0 &&
        examSessions.count == totalExams
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }

    private func randomColor() -> String {
        let colors = [
            "#007AFF", // Blue
            "#34C759", // Green
            "#FF9500", // Orange
            "#FF2D55", // Pink
            "#AF52DE", // Purple
            "#5AC8FA", // Light Blue
            "#FFCC00", // Yellow
            "#FF3B30"  // Red
        ]
        return colors.randomElement() ?? "#007AFF"
    }
}

// MARK: - Builder Structs

struct CohortBuilder: Identifiable {
    let id: UUID
    var name: String
    var colorHex: String
    var sortOrder: Int
    var isDefault: Bool
}

struct ExamSessionBuilder: Identifiable {
    let id: UUID
    let examNumber: Int
    var weekStartDate: Date
    var assignedCohortId: UUID?
    var theme: String?
    var durationMinutes: Int
    var bufferMinutes: Int
}

// MARK: - Date Extension

extension Date {
    var weekdayNumber: Int {
        Calendar.current.component(.weekday, from: self)
    }
}
