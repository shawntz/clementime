//
//  ExamStructureViewModel.swift
//  ClemenTime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import Combine

@MainActor
class ExamStructureViewModel: ObservableObject {
    @Published var nodes: [ExamStructureNode] = []
    @Published var connections: [NodeConnection] = []
    @Published var pendingConnection: (nodeId: UUID, port: NodePort)? = nil
    @Published var isLoading = false
    @Published var error: String?

    private let course: Course
    private lazy var courseRepository: CourseRepository = PersistenceController.shared.courseRepository

    init(course: Course) {
        self.course = course
    }

    func initialize() {
        loadStructure()
    }

    // MARK: - Node Operations

    func addNode(type: ExamNodeType, at position: CGPoint) {
        let node = ExamStructureNode(
            name: "\(type.displayName) \(nodes.count + 1)",
            type: type,
            position: position
        )
        nodes.append(node)
    }

    func moveNode(_ nodeId: UUID, by offset: CGSize) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        nodes[index].position.x += offset.width
        nodes[index].position.y += offset.height
    }

    func updateNode(_ updatedNode: ExamStructureNode) {
        guard let index = nodes.firstIndex(where: { $0.id == updatedNode.id }) else { return }
        nodes[index] = updatedNode
    }

    func deleteNode(_ nodeId: UUID) {
        // Remove connections associated with this node
        connections.removeAll { connection in
            connection.fromNodeId == nodeId || connection.toNodeId == nodeId
        }

        // Remove the node
        nodes.removeAll { $0.id == nodeId }
    }

    // MARK: - Connection Operations

    func startConnection(from nodeId: UUID, port: NodePort) {
        if let pending = pendingConnection {
            // Complete the connection
            completeConnection(to: nodeId, port: port, from: pending.nodeId, fromPort: pending.port)
            pendingConnection = nil
        } else {
            // Start a new connection
            pendingConnection = (nodeId, port)
        }
    }

    private func completeConnection(to toNodeId: UUID, port toPort: NodePort, from fromNodeId: UUID, fromPort: NodePort) {
        // Validate connection
        guard fromNodeId != toNodeId else { return }
        guard fromPort == .output && toPort == .input else { return }

        // Check for duplicate connection
        let isDuplicate = connections.contains { connection in
            connection.fromNodeId == fromNodeId && connection.toNodeId == toNodeId
        }
        guard !isDuplicate else { return }

        // Create connection with default sequential style
        let connection = NodeConnection(
            fromNodeId: fromNodeId,
            toNodeId: toNodeId,
            style: .sequential
        )
        connections.append(connection)
    }

    func deleteConnection(_ connectionId: UUID) {
        connections.removeAll { $0.id == connectionId }
    }

    func toggleConnectionStyle(_ connectionId: UUID) {
        guard let index = connections.firstIndex(where: { $0.id == connectionId }) else { return }
        let currentStyle = connections[index].style
        connections[index] = NodeConnection(
            id: connections[index].id,
            fromNodeId: connections[index].fromNodeId,
            toNodeId: connections[index].toNodeId,
            style: currentStyle == .sequential ? .parallel : .sequential
        )
    }

    // MARK: - Persistence

    func loadStructure() {
        // Load saved structure from course metadata
        guard let graphJSON = course.metadata["examStructureGraph"],
              let data = graphJSON.data(using: .utf8),
              let graph = try? JSONDecoder().decode(ExamStructureGraph.self, from: data) else {
            // No saved structure, start with empty canvas
            return
        }

        nodes = graph.nodes
        connections = graph.connections
    }

    func saveStructure() async {
        isLoading = true
        error = nil

        do {
            let graph = ExamStructureGraph(
                nodes: nodes,
                connections: connections,
                metadata: [
                    "version": "1.0",
                    "lastModified": ISO8601DateFormatter().string(from: Date())
                ]
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(graph)
            guard let jsonString = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "ExamStructure", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode graph"])
            }

            var updatedCourse = course
            updatedCourse.metadata["examStructureGraph"] = jsonString

            try await courseRepository.updateCourse(updatedCourse)

            isLoading = false
        } catch {
            self.error = "Failed to save structure: \(error.localizedDescription)"
            isLoading = false
        }
    }

    // MARK: - Validation

    func validateStructure() -> [String] {
        var errors: [String] = []

        // Check for cycles in sequential connections
        if hasCycles() {
            errors.append("Graph contains cycles in sequential connections")
        }

        // Check that student proportions sum to approximately 1.0 for nodes without cohorts
        let nodesWithoutCohorts = nodes.filter { $0.assignedCohort == nil }
        if !nodesWithoutCohorts.isEmpty {
            let totalProportion = nodesWithoutCohorts.reduce(0.0) { $0 + $1.studentProportion }
            if abs(totalProportion - 1.0) > 0.01 {
                errors.append("Student proportions for uncohorted nodes sum to \(Int(totalProportion * 100))% instead of 100%")
            }
        }

        // Check for orphaned nodes (no connections)
        if nodes.count > 1 {
            for node in nodes {
                let hasIncoming = connections.contains { $0.toNodeId == node.id }
                let hasOutgoing = connections.contains { $0.fromNodeId == node.id }
                if !hasIncoming && !hasOutgoing {
                    errors.append("Node '\(node.name)' has no connections")
                }
            }
        }

        return errors
    }

    private func hasCycles() -> Bool {
        var visited = Set<UUID>()
        var recursionStack = Set<UUID>()

        func dfs(_ nodeId: UUID) -> Bool {
            visited.insert(nodeId)
            recursionStack.insert(nodeId)

            // Get sequential outgoing connections
            let outgoing = connections.filter { $0.fromNodeId == nodeId && $0.style == .sequential }

            for connection in outgoing {
                if !visited.contains(connection.toNodeId) {
                    if dfs(connection.toNodeId) {
                        return true
                    }
                } else if recursionStack.contains(connection.toNodeId) {
                    return true // Cycle detected
                }
            }

            recursionStack.remove(nodeId)
            return false
        }

        for node in nodes {
            if !visited.contains(node.id) {
                if dfs(node.id) {
                    return true
                }
            }
        }

        return false
    }
}
