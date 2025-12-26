//
//  ExamSlotHistory.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct ExamSlotHistory: Identifiable, Codable, Hashable {
    let id: UUID
    let examSlotId: UUID
    let studentId: UUID
    let sectionId: UUID
    var examNumber: Int
    var weekNumber: Int
    var date: Date?
    var startTime: Date?
    var endTime: Date?
    var isScheduled: Bool
    var changedAt: Date
    var changedBy: String
    var reason: String

    init(
        id: UUID = UUID(),
        examSlotId: UUID,
        studentId: UUID,
        sectionId: UUID,
        examNumber: Int,
        weekNumber: Int,
        date: Date? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        isScheduled: Bool,
        changedAt: Date = Date(),
        changedBy: String,
        reason: String
    ) {
        self.id = id
        self.examSlotId = examSlotId
        self.studentId = studentId
        self.sectionId = sectionId
        self.examNumber = examNumber
        self.weekNumber = weekNumber
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.isScheduled = isScheduled
        self.changedAt = changedAt
        self.changedBy = changedBy
        self.reason = reason
    }

    var formattedTimeRange: String {
        guard let start = startTime, let end = endTime else {
            return "Not scheduled"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    var formattedDate: String {
        guard let date = date else {
            return "No date"
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var formattedChangedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: changedAt)
    }
}
