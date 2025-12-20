//
//  ExamStructureCanvasView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

// MARK: - Main Canvas View

struct ExamStructureCanvasView: View {
    let course: Course
    @StateObject private var viewModel: ExamStructureViewModel
    @State private var selectedNodeId: UUID?
    @State private var showNodePalette = false
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var showValidationErrors = false
    @State private var validationErrors: [String] = []

    init(course: Course) {
        self.course = course
        self._viewModel = StateObject(wrappedValue: ExamStructureViewModel(
            course: course,
            courseRepository: PersistenceController.shared.courseRepository
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas background
                Color(NSColor.controlBackgroundColor)
                    .ignoresSafeArea()

                // Grid overlay
                GridPattern()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)

                // Canvas content
                ZStack {
                    // Connection arrows (drawn first, behind nodes)
                    ForEach(viewModel.connections) { connection in
                        ConnectionArrow(
                            connection: connection,
                            nodes: viewModel.nodes,
                            isSelected: false
                        )
                        .onTapGesture {
                            // TODO: Select connection
                        }
                    }

                    // Exam session nodes
                    ForEach(viewModel.nodes) { node in
                        ExamSessionNodeView(
                            node: node,
                            isSelected: selectedNodeId == node.id,
                            onTap: {
                                selectedNodeId = node.id
                            },
                            onDrag: { offset in
                                viewModel.moveNode(node.id, by: offset)
                            },
                            onConnect: { sourcePort in
                                viewModel.startConnection(from: node.id, port: sourcePort)
                            }
                        )
                        .position(node.position)
                    }
                }
                .scaleEffect(canvasScale)
                .offset(canvasOffset)

                // Toolbar overlay
                VStack {
                    HStack {
                        // Node palette button
                        Button(action: { showNodePalette.toggle() }) {
                            Label("Add Node", systemImage: "plus.app.fill")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        // Zoom controls
                        HStack(spacing: 8) {
                            Button(action: { canvasScale *= 1.2 }) {
                                Image(systemName: "plus.magnifyingglass")
                            }

                            Button(action: { canvasScale = 1.0 }) {
                                Text("\(Int(canvasScale * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                            }

                            Button(action: { canvasScale *= 0.8 }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        // Validation button
                        Button(action: {
                            validationErrors = viewModel.validateStructure()
                            if !validationErrors.isEmpty {
                                showValidationErrors = true
                            }
                        }) {
                            Label("Validate", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)

                        // Save button
                        Button(action: {
                            Task {
                                await viewModel.saveStructure()
                            }
                        }) {
                            Label("Save Structure", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isLoading)
                    }
                    .padding()

                    Spacer()
                }

                // Node palette overlay
                if showNodePalette {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showNodePalette = false
                        }

                    NodePaletteView(
                        onCreateNode: { nodeType in
                            viewModel.addNode(type: nodeType, at: CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2))
                            showNodePalette = false
                        },
                        onClose: {
                            showNodePalette = false
                        }
                    )
                    .frame(width: 300)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(12)
                    .shadow(radius: 20)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if selectedNodeId == nil {
                            canvasOffset = CGSize(
                                width: canvasOffset.width + value.translation.width,
                                height: canvasOffset.height + value.translation.height
                            )
                        }
                    }
            )
        }
        .sheet(item: $selectedNodeId) { nodeId in
            if let node = viewModel.nodes.first(where: { $0.id == nodeId }) {
                NodeAttributesEditor(
                    node: node,
                    course: course,
                    onUpdate: { updatedNode in
                        viewModel.updateNode(updatedNode)
                    },
                    onDelete: {
                        viewModel.deleteNode(nodeId)
                        selectedNodeId = nil
                    }
                )
            }
        }
        .alert("Validation Errors", isPresented: $showValidationErrors) {
            Button("OK", role: .cancel) { }
        } message: {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(validationErrors, id: \.self) { error in
                    Text("• \(error)")
                }
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK", role: .cancel) {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
    }
}

// MARK: - Grid Pattern

struct GridPattern: Shape {
    var spacing: CGFloat = 30

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Vertical lines
        var x: CGFloat = 0
        while x <= rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }

        // Horizontal lines
        var y: CGFloat = 0
        while y <= rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }

        return path
    }
}

// MARK: - Exam Session Node View

struct ExamSessionNodeView: View {
    let node: ExamStructureNode
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: (CGSize) -> Void
    let onConnect: (NodePort) -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // Node header
            HStack {
                Image(systemName: node.type.icon)
                    .foregroundColor(.white)

                Text(node.type.displayName)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(8)
            .background(node.type.color)

            // Node content
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let cohort = node.assignedCohort {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: cohort.colorHex) ?? .blue)
                            .frame(width: 8, height: 8)
                        Text(cohort.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text("\(Int(node.studentProportion * 100))% of roster")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .frame(width: 180, alignment: .leading)

            // Connection ports
            HStack {
                // Input port (left)
                ConnectionPort(type: .input, isActive: false)
                    .onTapGesture {
                        onConnect(.input)
                    }

                Spacer()

                // Output port (right)
                ConnectionPort(type: .output, isActive: false)
                    .onTapGesture {
                        onConnect(.output)
                    }
            }
            .padding(.horizontal, -6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
        .offset(dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    onDrag(value.translation)
                    dragOffset = .zero
                }
        )
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Connection Port

struct ConnectionPort: View {
    let type: NodePort
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? Color.accentColor : Color.gray)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

// MARK: - Connection Arrow

struct ConnectionArrow: View {
    let connection: NodeConnection
    let nodes: [ExamStructureNode]
    let isSelected: Bool

    var body: some View {
        if let startNode = nodes.first(where: { $0.id == connection.fromNodeId }),
           let endNode = nodes.first(where: { $0.id == connection.toNodeId }) {

            let startPoint = getPortPosition(for: startNode, port: .output)
            let endPoint = getPortPosition(for: endNode, port: .input)

            ArrowPath(from: startPoint, to: endPoint, style: connection.style)
                .stroke(connection.style.color, lineWidth: isSelected ? 3 : 2)
                .shadow(color: Color.black.opacity(0.2), radius: 2)
        }
    }

    private func getPortPosition(for node: ExamStructureNode, port: NodePort) -> CGPoint {
        let nodeWidth: CGFloat = 180
        let nodeHeight: CGFloat = 100

        switch port {
        case .input:
            return CGPoint(x: node.position.x - nodeWidth / 2, y: node.position.y)
        case .output:
            return CGPoint(x: node.position.x + nodeWidth / 2, y: node.position.y)
        }
    }
}

// MARK: - Arrow Path Shape

struct ArrowPath: Shape {
    let from: CGPoint
    let to: CGPoint
    let style: ConnectionStyle

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch style {
        case .sequential:
            // Curved bezier for sequential (one after another)
            path.move(to: from)
            let controlPoint1 = CGPoint(x: from.x + (to.x - from.x) / 2, y: from.y)
            let controlPoint2 = CGPoint(x: from.x + (to.x - from.x) / 2, y: to.y)
            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)

        case .parallel:
            // Straight line for parallel (at same time)
            path.move(to: from)
            path.addLine(to: to)
        }

        // Add arrowhead
        addArrowhead(to: &path, at: to, from: from)

        return path
    }

    private func addArrowhead(to path: inout Path, at point: CGPoint, from source: CGPoint) {
        let arrowLength: CGFloat = 10
        let arrowWidth: CGFloat = 6

        let angle = atan2(point.y - source.y, point.x - source.x)

        let arrowPoint1 = CGPoint(
            x: point.x - arrowLength * cos(angle - .pi / 6),
            y: point.y - arrowLength * sin(angle - .pi / 6)
        )

        let arrowPoint2 = CGPoint(
            x: point.x - arrowLength * cos(angle + .pi / 6),
            y: point.y - arrowLength * sin(angle + .pi / 6)
        )

        path.move(to: arrowPoint1)
        path.addLine(to: point)
        path.addLine(to: arrowPoint2)
    }
}

// MARK: - Node Palette

struct NodePaletteView: View {
    let onCreateNode: (ExamNodeType) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add Exam Session")
                    .font(.headline)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(ExamNodeType.allCases, id: \.self) { nodeType in
                        Button(action: {
                            onCreateNode(nodeType)
                        }) {
                            HStack {
                                Image(systemName: nodeType.icon)
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(nodeType.color)
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nodeType.displayName)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text(nodeType.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

#Preview {
    ExamStructureCanvasView(course: Course(
        id: UUID(),
        name: "PSYCH 10",
        term: "Fall 2025",
        quarterStartDate: Date(),
        examDay: .friday,
        totalExams: 5,
        isActive: true,
        createdBy: UUID(),
        settings: CourseSettings()
    ))
}
