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
    var oddWeekDate: Date
    var evenWeekDate: Date
    var theme: String?
    var startTime: String // Format: "HH:MM"
    var endTime: String // Format: "HH:MM"
    var durationMinutes: Int
    var bufferMinutes: Int

    init(
        id: UUID = UUID(),
        courseId: UUID,
        examNumber: Int,
        oddWeekDate: Date,
        evenWeekDate: Date,
        theme: String? = nil,
        startTime: String = "13:30",
        endTime: String = "14:50",
        durationMinutes: Int = 7,
        bufferMinutes: Int = 1
    ) {
        self.id = id
        self.courseId = courseId
        self.examNumber = examNumber
        self.oddWeekDate = oddWeekDate
        self.evenWeekDate = evenWeekDate
        self.theme = theme
        self.startTime = startTime
        self.endTime = endTime
        self.durationMinutes = durationMinutes
        self.bufferMinutes = bufferMinutes
    }

    // Get date for specific cohort
    func date(for cohort: Cohort) -> Date {
        cohort.weekType == .odd ? oddWeekDate : evenWeekDate
    }

    // Get date for specific week type
    func date(for weekType: WeekType) -> Date {
        weekType == .odd ? oddWeekDate : evenWeekDate
    }

    // Formatted time range
    var formattedTimeRange: String {
        "\(startTime) - \(endTime)"
    }

    // Calculate total available exam time in minutes
    var totalAvailableMinutes: Int {
        guard let start = parseTime(startTime),
              let end = parseTime(endTime) else {
            return 0
        }
        return Int(end.timeIntervalSince(start) / 60)
    }

    // Calculate maximum number of students that can be scheduled
    var maxStudents: Int {
        let totalMinutes = totalAvailableMinutes
        let minutesPerStudent = durationMinutes + bufferMinutes
        return minutesPerStudent > 0 ? totalMinutes / minutesPerStudent : 0
    }

    private func parseTime(_ timeString: String) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var dateComponents = DateComponents()
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]

        return calendar.date(from: dateComponents)
    }
}
