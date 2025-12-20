//
//  CourseBuilderViewModel.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
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
    @Published var examDay: DayOfWeek = .friday
    @Published var totalExams = 5

    // Cohorts
    @Published var cohorts: [CohortBuilder] = []

    // Exam times
    @Published var examStartTime = Date()
    @Published var examEndTime = Date()
    @Published var examDurationMinutes = 7
    @Published var bufferMinutes = 1

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

        // Set default exam times
        let calendar = Calendar.current
        examStartTime = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: Date()) ?? Date()
        examEndTime = calendar.date(bySettingHour: 14, minute: 50, second: 0, of: Date()) ?? Date()

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
            weekType: .odd,
            colorHex: randomColor(),
            sortOrder: sortOrder
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
            CohortBuilder(id: UUID(), name: "A", weekType: .odd, colorHex: "#007AFF", sortOrder: 0),
            CohortBuilder(id: UUID(), name: "B", weekType: .even, colorHex: "#34C759", sortOrder: 1)
        ]
    }

    func generateExamSessions() {
        examSessions.removeAll()

        let calendar = Calendar.current
        var currentOddDate = quarterStartDate
        var currentEvenDate = quarterStartDate

        // Find first occurrence of exam day
        let targetWeekday = examDay.weekdayIndex
        while currentOddDate.weekdayNumber != targetWeekday {
            currentOddDate = calendar.date(byAdding: .day, value: 1, to: currentOddDate) ?? currentOddDate
        }
        currentEvenDate = calendar.date(byAdding: .day, value: 7, to: currentOddDate) ?? currentOddDate

        for examNumber in 1...totalExams {
            let session = ExamSessionBuilder(
                id: UUID(),
                examNumber: examNumber,
                oddWeekDate: currentOddDate,
                evenWeekDate: currentEvenDate,
                theme: nil,
                startTime: formatTime(examStartTime),
                endTime: formatTime(examEndTime),
                durationMinutes: examDurationMinutes,
                bufferMinutes: bufferMinutes
            )
            examSessions.append(session)

            // Advance dates by 2 weeks
            currentOddDate = calendar.date(byAdding: .day, value: 14, to: currentOddDate) ?? currentOddDate
            currentEvenDate = calendar.date(byAdding: .day, value: 14, to: currentEvenDate) ?? currentEvenDate
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
                examStartTime: TimeComponents(hour: Calendar.current.component(.hour, from: examStartTime),
                                              minute: Calendar.current.component(.minute, from: examStartTime)),
                examEndTime: TimeComponents(hour: Calendar.current.component(.hour, from: examEndTime),
                                            minute: Calendar.current.component(.minute, from: examEndTime)),
                examDurationMinutes: examDurationMinutes,
                examBufferMinutes: bufferMinutes,
                balancedTAScheduling: false
            )

            let input = CreateCourseInput(
                name: courseName,
                term: term,
                quarterStartDate: quarterStartDate,
                examDay: examDay,
                totalExams: totalExams,
                cohorts: cohorts.map { CohortInput(
                    name: $0.name,
                    weekType: $0.weekType,
                    colorHex: $0.colorHex,
                    sortOrder: $0.sortOrder
                )},
                examSessions: examSessions.map { ExamSessionInput(
                    examNumber: $0.examNumber,
                    oddWeekDate: $0.oddWeekDate,
                    evenWeekDate: $0.evenWeekDate,
                    theme: $0.theme,
                    startTime: $0.startTime,
                    endTime: $0.endTime,
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
    var weekType: WeekType
    var colorHex: String
    var sortOrder: Int
}

struct ExamSessionBuilder: Identifiable {
    let id: UUID
    let examNumber: Int
    var oddWeekDate: Date
    var evenWeekDate: Date
    var theme: String?
    var startTime: String
    var endTime: String
    var durationMinutes: Int
    var bufferMinutes: Int
}

// MARK: - Date Extension

extension Date {
    var weekdayNumber: Int {
        Calendar.current.component(.weekday, from: self)
    }
}
