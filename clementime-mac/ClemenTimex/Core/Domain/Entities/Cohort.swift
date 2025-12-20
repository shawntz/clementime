//
//  Cohort.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import SwiftUI

struct Cohort: Identifiable, Codable, Hashable {
    let id: UUID
    let courseId: UUID
    var name: String
    var weekType: WeekType
    var colorHex: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        courseId: UUID,
        name: String,
        weekType: WeekType,
        colorHex: String = "#3B82F6", // Default blue
        sortOrder: Int = 0
    ) {
        self.id = id
        self.courseId = courseId
        self.name = name
        self.weekType = weekType
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    // Computed property for SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

// MARK: - Week Type

enum WeekType: String, Codable, CaseIterable, Identifiable {
    case odd
    case even

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }

        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
