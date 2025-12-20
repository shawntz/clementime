//
//  Constraint.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct Constraint: Identifiable, Codable, Hashable {
    let id: UUID
    let studentId: UUID
    var type: ConstraintType
    var value: String
    var constraintDescription: String
    var isActive: Bool

    init(
        id: UUID = UUID(),
        studentId: UUID,
        type: ConstraintType,
        value: String,
        constraintDescription: String = "",
        isActive: Bool = true
    ) {
        self.id = id
        self.studentId = studentId
        self.type = type
        self.value = value
        self.constraintDescription = constraintDescription.isEmpty ? type.defaultDescription(value: value) : constraintDescription
        self.isActive = isActive
    }

    var displayDescription: String {
        constraintDescription.isEmpty ? type.defaultDescription(value: value) : constraintDescription
    }
}

// MARK: - Constraint Type

enum ConstraintType: String, Codable, CaseIterable, Identifiable {
    case timeBefore = "time_before"
    case timeAfter = "time_after"
    case weekPreference = "week_preference"
    case specificDate = "specific_date"
    case excludeDate = "exclude_date"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .timeBefore:
            return "Must finish before"
        case .timeAfter:
            return "Must start after"
        case .weekPreference:
            return "Week preference"
        case .specificDate:
            return "Specific date"
        case .excludeDate:
            return "Exclude date"
        }
    }

    var icon: String {
        switch self {
        case .timeBefore:
            return "clock.arrow.circlepath"
        case .timeAfter:
            return "clock.arrow.2.circlepath"
        case .weekPreference:
            return "calendar.badge.clock"
        case .specificDate:
            return "calendar.badge.plus"
        case .excludeDate:
            return "calendar.badge.minus"
        }
    }

    func defaultDescription(value: String) -> String {
        switch self {
        case .timeBefore:
            return "Must finish before \(value)"
        case .timeAfter:
            return "Must start after \(value)"
        case .weekPreference:
            return "Prefers \(value) weeks"
        case .specificDate:
            return "Must be on \(value)"
        case .excludeDate:
            return "Cannot be on \(value)"
        }
    }

    var requiresTime: Bool {
        self == .timeBefore || self == .timeAfter
    }

    var requiresDate: Bool {
        self == .specificDate || self == .excludeDate
    }

    var requiresWeekType: Bool {
        self == .weekPreference
    }
}
