//
//  ExamSessionEditorView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import SwiftUI

struct ExamSessionEditorView: View {
    @Environment(\.dismiss) var dismiss
    let course: Course
    let existingSession: ExamSession?
    let onSave: (ExamSession) -> Void

    @State private var sessionId: UUID
    @State private var examNumber: Int
    @State private var theme: String
    @State private var weekStartDate: Date
    @State private var durationMinutes: Int
    @State private var bufferMinutes: Int
    @State private var isForAllStudents: Bool
    @State private var selectedCohortId: UUID?

    @State private var availableCohorts: [Cohort] = []

    init(course: Course, existingSession: ExamSession? = nil, onSave: @escaping (ExamSession) -> Void) {
        self.course = course
        self.existingSession = existingSession
        self.onSave = onSave

        // Initialize with existing session or defaults
        if let session = existingSession {
            _sessionId = State(initialValue: session.id)
            _examNumber = State(initialValue: session.examNumber)
            _theme = State(initialValue: session.theme ?? "")
            _weekStartDate = State(initialValue: session.weekStartDate)
            _durationMinutes = State(initialValue: session.durationMinutes)
            _bufferMinutes = State(initialValue: session.bufferMinutes)
            _isForAllStudents = State(initialValue: session.assignedCohortId == nil)
            _selectedCohortId = State(initialValue: session.assignedCohortId)
        } else {
            _sessionId = State(initialValue: UUID())
            _examNumber = State(initialValue: 1)
            _theme = State(initialValue: "")
            _weekStartDate = State(initialValue: Date())
            _durationMinutes = State(initialValue: 30)
            _bufferMinutes = State(initialValue: 5)
            _isForAllStudents = State(initialValue: true)
            _selectedCohortId = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    Stepper(value: $examNumber, in: 1...20) {
                        HStack {
                            Text("Exam Number:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(examNumber)")
                                .fontWeight(.semibold)
                        }
                    }

                    HStack {
                        Text("Theme (optional)")
                            .foregroundColor(.secondary)
                        Spacer()
                        TextField("e.g., Cognition", text: $theme)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 200)
                    }
                } header: {
                    Text("Exam Details")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                SwiftUI.Section {
                    DatePicker("Week Starting", selection: $weekStartDate, displayedComponents: .date)

                    Stepper(value: $durationMinutes, in: 5...120, step: 1) {
                        HStack {
                            Text("Duration:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(durationMinutes) minutes")
                                .fontWeight(.semibold)
                        }
                    }

                    Stepper(value: $bufferMinutes, in: 0...30, step: 1) {
                        HStack {
                            Text("Buffer Time:")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(bufferMinutes) minutes")
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Schedule")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                SwiftUI.Section {
                    Toggle(isOn: $isForAllStudents) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("All Students")
                                .fontWeight(.medium)
                            Text("Schedule all students for oral exams")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !isForAllStudents {
                        Picker("Select Cohort", selection: $selectedCohortId) {
                            Text("Select a cohort").tag(nil as UUID?)
                            ForEach(availableCohorts, id: \.id) { cohort in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: cohort.colorHex) ?? .blue)
                                        .frame(width: 10, height: 10)
                                    Text(cohort.name)
                                }
                                .tag(cohort.id as UUID?)
                            }
                        }
                        .labelsHidden()
                    }
                } header: {
                    Text("Cohort Assignment")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existingSession == nil ? "Add Exam Session" : "Edit Exam Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExamSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
            .task {
                await loadCohorts()
            }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 450, idealHeight: 500)
    }

    private var isValid: Bool {
        examNumber > 0
    }

    private func saveExamSession() {
        let examSession = ExamSession(
            id: sessionId,
            courseId: course.id,
            examNumber: examNumber,
            weekStartDate: weekStartDate,
            assignedCohortId: isForAllStudents ? nil : selectedCohortId,
            theme: theme.isEmpty ? nil : theme,
            durationMinutes: durationMinutes,
            bufferMinutes: bufferMinutes
        )

        onSave(examSession)
        dismiss()
    }

    private func loadCohorts() async {
        do {
            let cohortRepo = PersistenceController.shared.cohortRepository
            availableCohorts = try await cohortRepo.fetchCohorts(courseId: course.id)
        } catch {
            print("Failed to load cohorts: \(error)")
        }
    }
}

#Preview {
    ExamSessionEditorView(
        course: Course(
            id: UUID(),
            name: "PSYCH 10",
            term: "Fall 2025",
            quarterStartDate: Date(),
            quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(),
            totalExams: 5,
            isActive: true,
            createdBy: UUID(),
            settings: CourseSettings()
        ),
        onSave: { _ in }
    )
}
