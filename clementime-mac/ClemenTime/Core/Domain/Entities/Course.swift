//
//  Course.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct Course: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var term: String
    var quarterStartDate: Date
    var quarterEndDate: Date
    var totalExams: Int
    var isActive: Bool
    var createdBy: UUID // User ID of creator
    var settings: CourseSettings
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        name: String,
        term: String,
        quarterStartDate: Date,
        quarterEndDate: Date,
        totalExams: Int = 5,
        isActive: Bool = true,
        createdBy: UUID,
        settings: CourseSettings = CourseSettings(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.term = term
        self.quarterStartDate = quarterStartDate
        self.quarterEndDate = quarterEndDate
        self.totalExams = totalExams
        self.isActive = isActive
        self.createdBy = createdBy
        self.settings = settings
        self.metadata = metadata
    }
}

// MARK: - Course Settings

struct CourseSettings: Codable, Hashable {
    var balancedTAScheduling: Bool
    var ignoredSectionCodes: [String]
    var navbarTitle: String?

    init(
        balancedTAScheduling: Bool = false,
        ignoredSectionCodes: [String] = [],
        navbarTitle: String? = nil
    ) {
        self.balancedTAScheduling = balancedTAScheduling
        self.ignoredSectionCodes = ignoredSectionCodes
        self.navbarTitle = navbarTitle
    }

    // Encode/decode to JSON string for Core Data storage
    func encode() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func decode(from json: String) -> CourseSettings {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8),
              let settings = try? decoder.decode(CourseSettings.self, from: data) else {
            return CourseSettings()
        }
        return settings
    }
}

// MARK: - Time Components

struct TimeComponents: Codable, Hashable {
    var hour: Int
    var minute: Int

    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    func toDate(baseDate: Date = Date()) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var components = calendar.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? baseDate
    }
}

// MARK: - Day of Week

enum DayOfWeek: String, Codable, CaseIterable, Identifiable {
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: String { rawValue }

    var weekdayIndex: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func from(weekday: Int) -> DayOfWeek {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return .friday
        }
    }
}
