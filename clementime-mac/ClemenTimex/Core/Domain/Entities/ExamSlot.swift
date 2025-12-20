//
//  ExamSlot.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct ExamSlot: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var studentId: UUID
    var sectionId: UUID
    var examSessionId: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var isScheduled: Bool
    var isLocked: Bool
    var notes: String?

    init(
        id: UUID = UUID(),
        courseId: UUID,
        studentId: UUID,
        sectionId: UUID,
        examSessionId: UUID,
        date: Date,
        startTime: Date,
        endTime: Date,
        isScheduled: Bool = false,
        isLocked: Bool = false,
        notes: String? = nil
    ) {
        self.id = id
        self.courseId = courseId
        self.studentId = studentId
        self.sectionId = sectionId
        self.examSessionId = examSessionId
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.isScheduled = isScheduled
        self.isLocked = isLocked
        self.notes = notes
    }

    // Computed properties
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var formattedTimeRange: String {
        if !isScheduled {
            return "Not scheduled"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    var isPast: Bool {
        date < Date()
    }

    var isUpcoming: Bool {
        date >= Date()
    }

    var canBeModified: Bool {
        !isLocked
    }
}

// MARK: - Schedule Generation Result

struct ScheduleResult {
    var scheduledCount: Int
    var unscheduledCount: Int
    var errors: [String]
    var unscheduledStudents: [UUID] // Student IDs that couldn't be scheduled

    var totalCount: Int {
        scheduledCount + unscheduledCount
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }

    var hasUnscheduled: Bool {
        unscheduledCount > 0
    }

    var successMessage: String {
        if hasUnscheduled {
            return "Scheduled \(scheduledCount) of \(totalCount) students. \(unscheduledCount) students need manual scheduling."
        } else {
            return "Successfully scheduled all \(scheduledCount) students."
        }
    }
}
