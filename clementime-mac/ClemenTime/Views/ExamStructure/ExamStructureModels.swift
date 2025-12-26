//
//  ExamStructureModels.swift
//  ClemenTime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

// MARK: - Exam Structure Node

struct ExamStructureNode: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ExamNodeType
    var position: CGPoint
    var assignedCohort: CohortInfo?
    var assignedTAs: [TAInfo]
    var studentProportion: Double // 0.0 to 1.0
    var rules: [ExamRule]
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        name: String,
        type: ExamNodeType,
        position: CGPoint,
        assignedCohort: CohortInfo? = nil,
        assignedTAs: [TAInfo] = [],
        studentProportion: Double = 1.0,
        rules: [ExamRule] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.position = position
        self.assignedCohort = assignedCohort
        self.assignedTAs = assignedTAs
        self.studentProportion = studentProportion
        self.rules = rules
        self.metadata = metadata
    }
}

// MARK: - Exam Node Type

enum ExamNodeType: String, Codable, CaseIterable {
    case standard = "standard"
    case makeup = "makeup"
    case practice = "practice"
    case final = "final"
    case midterm = "midterm"
    case conditional = "conditional"

    var displayName: String {
        switch self {
        case .standard: return "Standard Exam"
        case .makeup: return "Makeup Exam"
        case .practice: return "Practice Exam"
        case .final: return "Final Exam"
        case .midterm: return "Midterm Exam"
        case .conditional: return "Conditional Exam"
        }
    }

    var description: String {
        switch self {
        case .standard: return "Regular scheduled exam session"
        case .makeup: return "For students who missed an exam"
        case .practice: return "Practice run without grading"
        case .final: return "End-of-term final exam"
        case .midterm: return "Mid-term exam"
        case .conditional: return "Only scheduled based on conditions"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "doc.text"
        case .makeup: return "arrow.uturn.backward"
        case .practice: return "graduationcap"
        case .final: return "checkmark.seal"
        case .midterm: return "calendar.badge.clock"
        case .conditional: return "questionmark.diamond"
        }
    }

    var color: Color {
        switch self {
        case .standard: return .accentColor
        case .makeup: return Color(red: 0.9, green: 0.6, blue: 0.2)
        case .practice: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .final: return Color(red: 0.8, green: 0.2, blue: 0.4)
        case .midterm: return Color(red: 0.6, green: 0.4, blue: 0.9)
        case .conditional: return Color(red: 0.5, green: 0.5, blue: 0.5)
        }
    }
}

// MARK: - Node Connection

struct NodeConnection: Identifiable, Codable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
    let style: ConnectionStyle

    init(id: UUID = UUID(), fromNodeId: UUID, toNodeId: UUID, style: ConnectionStyle) {
        self.id = id
        self.fromNodeId = fromNodeId
        self.toNodeId = toNodeId
        self.style = style
    }
}

// MARK: - Connection Style

enum ConnectionStyle: String, Codable {
    case sequential = "sequential"  // One after another (curved arrow)
    case parallel = "parallel"      // At the same time (straight line)

    var color: Color {
        switch self {
        case .sequential: return .accentColor
        case .parallel: return .purple
        }
    }

    var displayName: String {
        switch self {
        case .sequential: return "Sequential (After)"
        case .parallel: return "Parallel (Same Time)"
        }
    }
}

// MARK: - Node Port

enum NodePort: String, Codable {
    case input
    case output
}

// MARK: - Cohort Info

struct CohortInfo: Codable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String

    init(id: UUID, name: String, colorHex: String) {
        self.id = id
        self.name = name
               self.colorHex = colorHex
    }

    init(from cohort: Cohort) {
        self.id = cohort.id
        self.name = cohort.name
        self.colorHex = cohort.colorHex
    }
}

// MARK: - TA Info

struct TAInfo: Codable, Hashable {
    let id: UUID
    let name: String

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Exam Rule

struct ExamRule: Identifiable, Codable, Hashable {
    let id: UUID
    var ruleType: ExamRuleType
    var value: String

    init(id: UUID = UUID(), ruleType: ExamRuleType, value: String) {
        self.id = id
        self.ruleType = ruleType
               self.value = value
    }
}

enum ExamRuleType: String, Codable, CaseIterable {
    case minStudents = "minStudents"
    case maxStudents = "maxStudents"
    case requiresPrevious = "requiresPrevious"
    case excludeIfCompleted = "excludeIfCompleted"
    case timeWindow = "timeWindow"

    var displayName: String {
        switch self {
        case .minStudents: return "Minimum Students"
        case .maxStudents: return "Maximum Students"
        case .requiresPrevious: return "Requires Previous Exam"
        case .excludeIfCompleted: return "Exclude If Completed"
        case .timeWindow: return "Time Window"
        }
    }
}

// MARK: - Exam Structure Graph

struct ExamStructureGraph: Codable {
    var nodes: [ExamStructureNode]
    var connections: [NodeConnection]
    var metadata: [String: String]

    init(nodes: [ExamStructureNode] = [], connections: [NodeConnection] = [], metadata: [String: String] = [:]) {
        self.nodes = nodes
        self.connections = connections
        self.metadata = metadata
    }
}
