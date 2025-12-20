//
//  SectionEditorView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

struct SectionEditorView: View {
    let courseId: UUID
    let section: Section?
    let onSave: (Section) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var sectionName = ""
    @State private var sectionCode = ""
    @State private var roomNumber = ""
    @State private var selectedTAId: UUID?
    @State private var selectedCohortId: UUID?
    @State private var examDate = Date()
    @State private var examStartTime = Date()
    @State private var examEndTime = Date()

    @StateObject private var taViewModel = TAUsersViewModel()
    @StateObject private var cohortViewModel = CohortsViewModel()

    init(courseId: UUID, section: Section?, onSave: @escaping (Section) -> Void) {
        self.courseId = courseId
        self.section = section
        self.onSave = onSave

        // Initialize state from existing section
        if let section = section {
            _sectionName = State(initialValue: section.name)
            _sectionCode = State(initialValue: section.code)
            _roomNumber = State(initialValue: section.location)
            _selectedTAId = State(initialValue: section.assignedTAId)
            _selectedCohortId = State(initialValue: section.cohortId)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Section Information") {
                    TextField("Section Name", text: $sectionName)
                        .textFieldStyle(.plain)

                    TextField("Section Code (e.g., F25-PSYCH-10-02)", text: $sectionCode)
                        .textFieldStyle(.plain)

                    TextField("Room Number", text: $roomNumber)
                        .textFieldStyle(.plain)
                }

                Section("Exam Schedule") {
                    DatePicker("Exam Date", selection: $examDate, displayedComponents: .date)

                    DatePicker("Start Time", selection: $examStartTime, displayedComponents: .hourAndMinute)

                    DatePicker("End Time", selection: $examEndTime, displayedComponents: .hourAndMinute)
                }

                Section("Assignment") {
                    Picker("Cohort", selection: $selectedCohortId) {
                        Text("Select Cohort").tag(nil as UUID?)
                        ForEach(cohortViewModel.cohorts) { cohort in
                            Text(cohort.name).tag(cohort.id as UUID?)
                        }
                    }

                    Picker("Assigned TA", selection: $selectedTAId) {
                        Text("No TA Assigned").tag(nil as UUID?)
                        ForEach(taViewModel.taUsers) { ta in
                            Text("\(ta.firstName) \(ta.lastName)").tag(ta.id as UUID?)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(section == nil ? "New Section" : "Edit Section")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(section == nil ? "Create" : "Save") {
                        saveSection()
                    }
                    .disabled(!isValid)
                }
            }
            .task {
                taViewModel.courseId = courseId
                await taViewModel.loadTAUsers()
                cohortViewModel.courseId = courseId
                await cohortViewModel.loadCohorts()
            }
        }
        .frame(width: 600, height: 550)
    }

    private var isValid: Bool {
        !sectionName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sectionCode.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedCohortId != nil
    }

    private func saveSection() {
        let newSection = Section(
            id: section?.id ?? UUID(),
            courseId: courseId,
            code: sectionCode.trimmingCharacters(in: .whitespaces),
            name: sectionName.trimmingCharacters(in: .whitespaces),
            location: roomNumber.trimmingCharacters(in: .whitespaces),
            assignedTAId: selectedTAId,
            cohortId: selectedCohortId ?? UUID(),
            isActive: true
        )

        onSave(newSection)
        dismiss()
    }
}

// MARK: - TA Users ViewModel

@MainActor
class TAUsersViewModel: ObservableObject {
    @Published var taUsers: [TAUser] = []
    @Published var isLoading = false
    @Published var error: String?

    var courseId: UUID?
    private let taUserRepository: TAUserRepository

    init(taUserRepository: TAUserRepository = PersistenceController.shared.taUserRepository) {
        self.taUserRepository = taUserRepository
    }

    func loadTAUsers() async {
        guard let courseId = courseId else { return }

        isLoading = true
        error = nil

        do {
            taUsers = try await taUserRepository.fetchTAUsers(courseId: courseId)
        } catch {
            self.error = "Failed to load TAs: \(error.localizedDescription)"
            print("Error loading TAs: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Cohorts ViewModel

@MainActor
class CohortsViewModel: ObservableObject {
    @Published var cohorts: [Cohort] = []
    @Published var isLoading = false
    @Published var error: String?

    var courseId: UUID?
    private let cohortRepository: CohortRepository

    init(cohortRepository: CohortRepository = PersistenceController.shared.cohortRepository) {
        self.cohortRepository = cohortRepository
    }

    func loadCohorts() async {
        guard let courseId = courseId else { return }

        isLoading = true
        error = nil

        do {
            cohorts = try await cohortRepository.fetchCohorts(courseId: courseId)
        } catch {
            self.error = "Failed to load cohorts: \(error.localizedDescription)"
            print("Error loading cohorts: \(error)")
        }

        isLoading = false
    }
}

#Preview {
    SectionEditorView(courseId: UUID(), section: nil, onSave: { _ in })
}
