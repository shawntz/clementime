//
//  NodeAttributesEditor.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct NodeAttributesEditor: View {
    @Environment(\.dismiss) var dismiss
    @State private var editedNode: ExamStructureNode
    @State private var availableCohorts: [CohortInfo] = []
    @State private var availableTAs: [TAInfo] = []
    @State private var showAddRule = false
    @State private var newRuleType: ExamRuleType = .minStudents
    @State private var newRuleValue: String = ""

    let course: Course
    let onUpdate: (ExamStructureNode) -> Void
    let onDelete: () -> Void

    init(node: ExamStructureNode, course: Course, onUpdate: @escaping (ExamStructureNode) -> Void, onDelete: @escaping () -> Void) {
        self.course = course
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._editedNode = State(initialValue: node)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Basic Information
                Section("Basic Information") {
                    HStack {
                        Image(systemName: editedNode.type.icon)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(editedNode.type.color)
                            .cornerRadius(8)

                        VStack(alignment: .leading) {
                            Text(editedNode.type.displayName)
                                .font(.headline)
                            Text(editedNode.type.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    TextField("Node Name", text: $editedNode.name)
                }

                // Cohort Assignment
                Section("Cohort Assignment") {
                    if availableCohorts.isEmpty {
                        Text("No cohorts configured for this course")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Picker("Assigned Cohort", selection: $editedNode.assignedCohort) {
                            Text("All Students (No Cohort)").tag(nil as CohortInfo?)
                            ForEach(availableCohorts, id: \.id) { cohort in
                                HStack {
                                    Circle()
                                        .fill(Color(hex: cohort.colorHex) ?? .blue)
                                        .frame(width: 12, height: 12)
                                    Text(cohort.name)
                                }
                                .tag(cohort as CohortInfo?)
                            }
                        }
                    }
                }

                // TA Assignments
                Section("TA Assignments") {
                    if availableTAs.isEmpty {
                        Text("No TAs configured for this course")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        List {
                            ForEach(availableTAs, id: \.id) { ta in
                                Toggle(ta.name, isOn: taBinding(for: ta.id))
                            }
                        }
                        .frame(height: min(CGFloat(availableTAs.count) * 30, 150))
                    }
                }

                // Student Proportion
                Section("Student Proportion") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Proportion of Roster")
                            Spacer()
                            Text("\(Int(editedNode.studentProportion * 100))%")
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }

                        Slider(value: $editedNode.studentProportion, in: 0.0...1.0, step: 0.05)
                            .accentColor(.orange)

                        Text("Determines what percentage of the total roster will be scheduled for this exam session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Rules
                Section("Scheduling Rules") {
                    ForEach(editedNode.rules) { rule in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.ruleType.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(rule.value)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                deleteRule(rule.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(action: { showAddRule = true }) {
                        Label("Add Rule", systemImage: "plus.circle")
                    }
                }

                // Metadata
                Section("Metadata") {
                    ForEach(Array(editedNode.metadata.keys.sorted()), id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(editedNode.metadata[key] ?? "")
                                .font(.caption)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Exam Session Node")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onUpdate(editedNode)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $showAddRule) {
                AddRuleSheet(
                    ruleType: $newRuleType,
                    ruleValue: $newRuleValue,
                    onAdd: {
                        addRule()
                        showAddRule = false
                    },
                    onCancel: {
                        showAddRule = false
                    }
                )
            }
            .task {
                await loadCohorts()
                await loadTAs()
            }
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - Helper Methods

    private func taBinding(for taId: UUID) -> Binding<Bool> {
        Binding(
            get: { editedNode.assignedTAs.contains(where: { $0.id == taId }) },
            set: { isSelected in
                if isSelected {
                    if let ta = availableTAs.first(where: { $0.id == taId }) {
                        editedNode.assignedTAs.append(ta)
                    }
                } else {
                    editedNode.assignedTAs.removeAll { $0.id == taId }
                }
            }
        )
    }

    private func addRule() {
        let rule = ExamRule(ruleType: newRuleType, value: newRuleValue)
        editedNode.rules.append(rule)
        newRuleValue = ""
    }

    private func deleteRule(_ ruleId: UUID) {
        editedNode.rules.removeAll { $0.id == ruleId }
    }

    private func loadCohorts() async {
        // Load cohorts from course
        do {
            let cohortRepo = PersistenceController.shared.cohortRepository
            let cohorts = try await cohortRepo.fetchCohorts(courseId: course.id)
            availableCohorts = cohorts.map { CohortInfo(from: $0) }
        } catch {
            print("Failed to load cohorts: \(error)")
        }
    }

    private func loadTAs() async {
        // Load TAs from course
        do {
            let taRepo = PersistenceController.shared.taUserRepository
            let tas = try await taRepo.fetchTAUsers(courseId: course.id)
            availableTAs = tas.map { TAInfo(id: $0.id, name: "\($0.firstName) \($0.lastName)") }
        } catch {
            print("Failed to load TAs: \(error)")
        }
    }
}

// MARK: - Add Rule Sheet

struct AddRuleSheet: View {
    @Binding var ruleType: ExamRuleType
    @Binding var ruleValue: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Rule Configuration") {
                    Picker("Rule Type", selection: $ruleType) {
                        ForEach(ExamRuleType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    TextField("Value", text: $ruleValue)
                        .textFieldStyle(.roundedBorder)

                    Text(ruleTypeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Scheduling Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                    }
                    .disabled(ruleValue.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 400, height: 250)
    }

    private var ruleTypeDescription: String {
        switch ruleType {
        case .minStudents:
            return "Minimum number of students required for this session (e.g., '5')"
        case .maxStudents:
            return "Maximum number of students allowed in this session (e.g., '20')"
        case .requiresPrevious:
            return "Students must have completed a previous exam (e.g., 'Exam 1')"
        case .excludeIfCompleted:
            return "Exclude students who completed another exam (e.g., 'Practice Exam')"
        case .timeWindow:
            return "Time window for this session (e.g., '9:00 AM - 11:00 AM')"
        }
    }
}

#Preview {
    NodeAttributesEditor(
        node: ExamStructureNode(
            name: "Standard Exam 1",
            type: .standard,
            position: CGPoint(x: 100, y: 100),
            studentProportion: 0.5
        ),
        course: Course(
            id: UUID(),
            name: "PSYCH 10",
            term: "Fall 2025",
            quarterStartDate: Date(),
            examDay: .friday,
            totalExams: 5,
            isActive: true,
            createdBy: UUID(),
            settings: CourseSettings()
        ),
        onUpdate: { _ in },
        onDelete: { }
    )
}
