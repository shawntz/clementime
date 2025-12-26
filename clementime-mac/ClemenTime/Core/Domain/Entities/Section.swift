//
//  Section.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct Section: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var code: String
    var name: String
    var location: String
    var assignedTAId: UUID?
    var weekday: Int // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    var startTime: String // Format: "HH:MM"
    var endTime: String // Format: "HH:MM"
    var isActive: Bool
    var shouldIgnoreForMatching: Bool // true for lecture sections that should be ignored during roster import

    init(
        id: UUID = UUID(),
        courseId: UUID,
        code: String,
        name: String,
        location: String = "",
        assignedTAId: UUID? = nil,
        weekday: Int = 6, // Default to Friday
        startTime: String = "13:30",
        endTime: String = "14:50",
        isActive: Bool = true,
        shouldIgnoreForMatching: Bool = false
    ) {
        self.id = id
        self.courseId = courseId
        self.code = code
        self.name = name
        self.location = location
        self.assignedTAId = assignedTAId
        self.weekday = weekday
        self.startTime = startTime
        self.endTime = endTime
        self.isActive = isActive
        self.shouldIgnoreForMatching = shouldIgnoreForMatching
    }

    var displayName: String {
        "\(code) - \(name)"
    }

    var hasAssignedTA: Bool {
        assignedTAId != nil
    }

    var weekdayName: String {
        let weekdays = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return weekdays[safe: weekday] ?? "Unknown"
    }

    var formattedTimeRange: String {
        "\(startTime) - \(endTime)"
    }

    // Calculate total available time in minutes
    var totalAvailableMinutes: Int {
        guard let start = parseTime(startTime),
              let end = parseTime(endTime) else {
            return 0
        }
        return Int(end.timeIntervalSince(start) / 60)
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

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
