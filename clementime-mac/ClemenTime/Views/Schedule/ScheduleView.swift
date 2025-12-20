//
//  ScheduleView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

struct ScheduleView: View {
    let course: Course
    @StateObject private var viewModel: ScheduleViewModel
    @State private var showGenerateConfirmation = false
    @State private var selectedSlot: ExamSlot.ID?

    init(course: Course) {
        self.course = course
        // TODO: Inject dependencies properly via DI container
        let persistence = PersistenceController.shared
        self._viewModel = StateObject(wrappedValue: ScheduleViewModel(
            course: course,
            scheduleRepository: persistence.scheduleRepository,
            studentRepository: persistence.studentRepository,
            sectionRepository: persistence.sectionRepository,
            examSessionRepository: persistence.examSessionRepository,
            generateScheduleUseCase: GenerateScheduleUseCase(
                courseRepository: persistence.courseRepository,
                cohortRepository: persistence.cohortRepository,
                studentRepository: persistence.studentRepository,
                sectionRepository: persistence.sectionRepository,
                examSessionRepository: persistence.examSessionRepository,
                constraintRepository: persistence.constraintRepository,
                scheduleRepository: persistence.scheduleRepository
            ),
            exportScheduleUseCase: ExportScheduleUseCase(
                courseRepository: persistence.courseRepository,
                studentRepository: persistence.studentRepository,
                sectionRepository: persistence.sectionRepository,
                scheduleRepository: persistence.scheduleRepository,
                examSessionRepository: persistence.examSessionRepository
            ),
            permissionChecker: PermissionChecker.mock
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Main content
            if viewModel.isLoading {
                ProgressView("Loading schedule...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.examSlots.isEmpty {
                emptyState
            } else {
                scheduleTable
            }
        }
        .task {
            await viewModel.loadData()
        }
        .alert("Generate Schedule", isPresented: $showGenerateConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Generate", role: .destructive) {
                Task {
                    await viewModel.generateSchedule()
                }
            }
        } message: {
            Text("This will regenerate all exam slots. Any manual changes will be lost. Continue?")
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error)
            }
        }
        .alert("Success", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.successMessage = nil
            }
        } message: {
            if let success = viewModel.successMessage {
                Text(success)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 16) {
            // Exam filter
            Picker("Exam", selection: $viewModel.selectedExamNumber) {
                ForEach(1...course.totalExams, id: \.self) { examNum in
                    Text("Exam \(examNum)").tag(examNum)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            Spacer()

            // Stats
            statsView

            Spacer()

            // Actions
            Button(action: {
                Task {
                    await viewModel.exportSchedule(examNumber: viewModel.selectedExamNumber)
                }
            }) {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(!viewModel.canEditSchedule)

            Button(action: {
                showGenerateConfirmation = true
            }) {
                Label("Generate Schedule", systemImage: "wand.and.stars")
            }
            .disabled(!viewModel.canEditSchedule || viewModel.isGenerating)
            .buttonStyle(.borderedProminent)

            if viewModel.isGenerating {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
    }

    private var statsView: some View {
        HStack(spacing: 20) {
            StatBadge(
                label: "Scheduled",
                value: viewModel.scheduledCount,
                color: .green
            )

            StatBadge(
                label: "Unscheduled",
                value: viewModel.unscheduledCount,
                color: .orange
            )

            StatBadge(
                label: "Locked",
                value: viewModel.lockedCount,
                color: .blue
            )
        }
    }

    // MARK: - Schedule Table

    private var scheduleTable: some View {
        Table(viewModel.filteredSlots, selection: $selectedSlot) {
            TableColumn("Time") { slot in
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.formattedTimeRange)
                        .font(.system(.body, design: .monospaced))
                    Text(slot.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 120, ideal: 150)

            TableColumn("Student") { slot in
                if let student = viewModel.students.first(where: { $0.id == slot.studentId }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.fullName)
                            .font(.body)
                        Text(student.email)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Unknown")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 150, ideal: 250)

            TableColumn("Section") { slot in
                if let section = viewModel.sections.first(where: { $0.id == slot.sectionId }) {
                    Text(section.name)
                        .font(.body)
                } else {
                    Text("-")
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn("Status") { slot in
                HStack(spacing: 8) {
                    if slot.isScheduled {
                        Label("Scheduled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Label("Unscheduled", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }

                    if slot.isLocked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }
            .width(min: 120, ideal: 150)

            TableColumn("Notes") { slot in
                Text(slot.notes ?? "-")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .width(min: 100, ideal: 200)

            TableColumn("Actions") { slot in
                HStack(spacing: 8) {
                    Button(action: {
                        Task {
                            if slot.isLocked {
                                await viewModel.unlockSlot(slot)
                            } else {
                                await viewModel.lockSlot(slot)
                            }
                        }
                    }) {
                        Image(systemName: slot.isLocked ? "lock.open" : "lock")
                            .foregroundColor(slot.isLocked ? .orange : .blue)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canEditSchedule)
                    .help(slot.isLocked ? "Unlock slot" : "Lock slot")
                }
            }
            .width(min: 60, ideal: 80)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Exam Slots")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Generate a schedule to create exam slots for your students")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.canEditSchedule {
                Button(action: {
                    Task {
                        await viewModel.generateSchedule()
                    }
                }) {
                    Label("Generate Schedule", systemImage: "wand.and.stars")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Mock Permission Checker

extension PermissionChecker {
    static var mock: PermissionChecker {
        PermissionChecker(
            currentUser: TAUser(
                id: UUID(),
                courseId: UUID(),
                firstName: "Test",
                lastName: "User",
                email: "test@example.com",
                username: "test",
                role: .admin,
                customPermissions: [],
                location: "",
                slackId: nil,
                isActive: true
            ),
            course: Course(
                id: UUID(),
                name: "Test",
                term: "Test",
                quarterStartDate: Date(),
                examDay: .friday,
                totalExams: 5,
                isActive: true,
                createdBy: UUID(),
                settings: CourseSettings()
            )
        )
    }
}

#Preview {
    ScheduleView(course: Course(
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
