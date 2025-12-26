//
//  SectionEditorView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import Combine

struct SectionEditorView: View {
    let courseId: UUID
    let section: Section?
    let onSave: (Section) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var sectionName = ""
    @State private var sectionCode = ""
    @State private var roomNumber = ""
    @State private var selectedTAId: UUID?
    @State private var selectedWeekday: DayOfWeek = .friday
    @State private var sectionStartTime = Calendar.current.date(from: DateComponents(hour: 13, minute: 30)) ?? Date()
    @State private var sectionEndTime = Calendar.current.date(from: DateComponents(hour: 14, minute: 50)) ?? Date()
    @State private var shouldIgnoreForMatching = false

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
            _selectedWeekday = State(initialValue: DayOfWeek.from(weekday: section.weekday))
            _shouldIgnoreForMatching = State(initialValue: section.shouldIgnoreForMatching)

            // Parse time strings to Dates
            if let startTime = parseTime(section.startTime) {
                _sectionStartTime = State(initialValue: startTime)
            }
            if let endTime = parseTime(section.endTime) {
                _sectionEndTime = State(initialValue: endTime)
            }
        }
    }

    private func parseTime(_ timeString: String) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 else { return nil }

        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = components[0]
        dateComponents.minute = components[1]
        return calendar.date(from: dateComponents)
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Section Information") {
                    TextField("Section Name", text: $sectionName)
                        .textFieldStyle(.plain)

                    TextField("Section Code (e.g., F25-PSYCH-10-02)", text: $sectionCode)
                        .textFieldStyle(.plain)

                    TextField("Room Number", text: $roomNumber)
                        .textFieldStyle(.plain)
                }

                SwiftUI.Section("Section Schedule") {
                    Picker("Weekday", selection: $selectedWeekday) {
                        ForEach(DayOfWeek.allCases) { day in
                            Text(day.rawValue.capitalized).tag(day)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Start Time", selection: $sectionStartTime, displayedComponents: .hourAndMinute)

                    DatePicker("End Time", selection: $sectionEndTime, displayedComponents: .hourAndMinute)
                }

                SwiftUI.Section("Assignment") {
                    Picker("Assigned TA", selection: $selectedTAId) {
                        Text("No TA Assigned").tag(nil as UUID?)
                        ForEach(taViewModel.taUsers) { ta in
                            Text("\(ta.firstName) \(ta.lastName)").tag(ta.id as UUID?)
                        }
                    }
                }

                SwiftUI.Section {
                    Toggle(isOn: $shouldIgnoreForMatching) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ignore for roster matching")
                                .fontWeight(.medium)
                            Text("Enable this for lecture sections that shouldn't be matched during CSV imports")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Import Settings")
                        .font(.headline)
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
        !sectionCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func saveSection() {
        // Extract time components from the DatePickers
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: sectionStartTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: sectionEndTime)

        let newSection = Section(
            id: section?.id ?? UUID(),
            courseId: courseId,
            code: sectionCode.trimmingCharacters(in: .whitespaces),
            name: sectionName.trimmingCharacters(in: .whitespaces),
            location: roomNumber.trimmingCharacters(in: .whitespaces),
            assignedTAId: selectedTAId,
            weekday: selectedWeekday.weekdayIndex,
            startTime: String(format: "%02d:%02d", startComponents.hour ?? 13, startComponents.minute ?? 30),
            endTime: String(format: "%02d:%02d", endComponents.hour ?? 14, endComponents.minute ?? 50),
            isActive: true,
            shouldIgnoreForMatching: shouldIgnoreForMatching
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
    private lazy var taUserRepository: TAUserRepository = PersistenceController.shared.taUserRepository

    init() {
        // Repository will be lazily initialized on first access
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
    private lazy var cohortRepository: CohortRepository = PersistenceController.shared.cohortRepository

    init() {
        // Repository will be lazily initialized on first access
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
