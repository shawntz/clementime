//
//  ExamSession.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct ExamSession: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var examNumber: Int
    var weekStartDate: Date // The start of the week when this exam occurs
    var assignedCohortId: UUID? // nil means "All Students", otherwise specific cohort
    var theme: String? // Optional name like "Midterm", "Final", "Week 1", etc.
    var durationMinutes: Int // Duration of each student's exam
    var bufferMinutes: Int // Buffer time between students

    init(
        id: UUID = UUID(),
        courseId: UUID,
        examNumber: Int,
        weekStartDate: Date,
        assignedCohortId: UUID? = nil, // nil = "All Students"
        theme: String? = nil,
        durationMinutes: Int = 7,
        bufferMinutes: Int = 1
    ) {
        self.id = id
        self.courseId = courseId
        self.examNumber = examNumber
        self.weekStartDate = weekStartDate
        self.assignedCohortId = assignedCohortId
        self.theme = theme
        self.durationMinutes = durationMinutes
        self.bufferMinutes = bufferMinutes
    }

    // Calculate the actual date for a section based on its weekday
    func date(for sectionWeekday: Int) -> Date {
        // sectionWeekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: weekStartDate)
        let daysToAdd = (sectionWeekday - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysToAdd, to: weekStartDate) ?? weekStartDate
    }

    // Check if this exam is for all students
    var isForAllStudents: Bool {
        assignedCohortId == nil
    }

    // Display name
    var displayName: String {
        if let theme = theme, !theme.isEmpty {
            return theme
        }
        return "Exam \(examNumber)"
    }
}
