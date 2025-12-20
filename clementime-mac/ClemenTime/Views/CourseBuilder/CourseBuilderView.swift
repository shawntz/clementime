//
//  CourseBuilderView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct CourseBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var viewModel: CourseBuilderViewModel
    @State private var currentStep = 0

    init() {
        // TODO: Inject dependencies properly
        self._viewModel = State(initialValue: CourseBuilderViewModel(
            createCourseUseCase: CreateCourseUseCase(
                courseRepository: PersistenceController.shared.courseRepository,
                cohortRepository: PersistenceController.shared.cohortRepository,
                examSessionRepository: PersistenceController.shared.examSessionRepository
            ),
            currentUserId: UUID() // TODO: Get current user ID
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                Divider()

                // Content
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Create New Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 700, height: 600)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps.count, id: \.self) { index in
                StepIndicator(
                    number: index + 1,
                    title: steps[index].title,
                    isActive: index == currentStep,
                    isCompleted: index < currentStep
                )

                if index < steps.count - 1 {
                    Divider()
                        .frame(height: 1)
                        .background(index < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding()
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch currentStep {
                case 0:
                    basicInfoStep
                case 1:
                    cohortsStep
                case 2:
                    examTimesStep
                case 3:
                    reviewStep
                default:
                    EmptyView()
                }
            }
            .padding()
        }
    }

    // MARK: - Steps

    private var basicInfoStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Course Information")
                .font(.title2)
                .fontWeight(.semibold)

            TextField("Course Name (e.g., PSYCH 10 / STATS 60)", text: $viewModel.courseName)
                .textFieldStyle(.roundedBorder)

            TextField("Term (e.g., Fall 2025)", text: $viewModel.term)
                .textFieldStyle(.roundedBorder)

            DatePicker("Quarter Start Date", selection: $viewModel.quarterStartDate, displayedComponents: .date)

            Picker("Exam Day", selection: $viewModel.examDay) {
                ForEach(DayOfWeek.allCases) { day in
                    Text(day.rawValue.capitalized).tag(day)
                }
            }

            Stepper("Total Exams: \(viewModel.totalExams)", value: $viewModel.totalExams, in: 1...20)
        }
    }

    private var cohortsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cohorts")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: {
                    viewModel.addCohort()
                }) {
                    Label("Add Cohort", systemImage: "plus")
                }
            }

            Text("Create cohorts to divide students into different exam schedules (e.g., odd week vs even week)")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(Array(viewModel.cohorts.enumerated()), id: \.element.id) { index, cohort in
                CohortRow(
                    cohort: $viewModel.cohorts[index],
                    onDelete: {
                        viewModel.deleteCohort(at: index)
                    }
                )
            }

            if viewModel.cohorts.isEmpty {
                Button(action: viewModel.addDefaultCohorts) {
                    Label("Add Default Cohorts (A & B)", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var examTimesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exam Times")
                .font(.title2)
                .fontWeight(.semibold)

            DatePicker("Start Time", selection: $viewModel.examStartTime, displayedComponents: .hourAndMinute)
            DatePicker("End Time", selection: $viewModel.examEndTime, displayedComponents: .hourAndMinute)

            Stepper("Duration: \(viewModel.examDurationMinutes) minutes", value: $viewModel.examDurationMinutes, in: 1...60)

            Stepper("Buffer: \(viewModel.bufferMinutes) minutes", value: $viewModel.bufferMinutes, in: 0...30)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please review your course settings before creating:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    ReviewRow(label: "Course Name", value: viewModel.courseName)
                    ReviewRow(label: "Term", value: viewModel.term)
                    ReviewRow(label: "Start Date", value: viewModel.quarterStartDate.formatted(date: .long, time: .omitted))
                    ReviewRow(label: "Exam Day", value: viewModel.examDay.rawValue.capitalized)
                    ReviewRow(label: "Total Exams", value: "\(viewModel.totalExams)")
                    ReviewRow(label: "Cohorts", value: "\(viewModel.cohorts.count)")
                }
            }

            if viewModel.isCreating {
                ProgressView("Creating course...")
                    .frame(maxWidth: .infinity)
                    .padding()
            }

            if let error = viewModel.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    currentStep -= 1
                }
            }

            Spacer()

            if currentStep < steps.count - 1 {
                Button("Next") {
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed)
            } else {
                Button("Create Course") {
                    createCourse()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.isValid || viewModel.isCreating)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var steps: [(title: String, validate: () -> Bool)] {
        [
            ("Basic Info", { !viewModel.courseName.isEmpty && !viewModel.term.isEmpty }),
            ("Cohorts", { !viewModel.cohorts.isEmpty }),
            ("Exam Times", { true }),
            ("Review", { viewModel.isValid })
        ]
    }

    private var canProceed: Bool {
        steps[currentStep].validate()
    }

    private func createCourse() {
        Task {
            if let course = await viewModel.createCourse() {
                dismiss()
            }
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.accentColor : (isCompleted ? Color.green : Color.secondary.opacity(0.2)))
                    .frame(width: 32, height: 32)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                        .font(.caption.weight(.bold))
                } else {
                    Text("\(number)")
                        .foregroundColor(isActive ? .white : .secondary)
                        .font(.caption.weight(.semibold))
                }
            }

            Text(title)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
}

// MARK: - Cohort Row

struct CohortRow: View {
    @Binding var cohort: CohortBuilder

    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("", selection: Binding(
                get: { Color(hex: cohort.colorHex) ?? .blue },
                set: { cohort.colorHex = $0.toHex() }
            ))
            .labelsHidden()
            .frame(width: 40)

            TextField("Cohort Name", text: $cohort.name)
                .textFieldStyle(.roundedBorder)

            Picker("Week Type", selection: $cohort.weekType) {
                Text("Odd").tag(WeekType.odd)
                Text("Even").tag(WeekType.even)
            }
            .pickerStyle(.segmented)
            .frame(width: 150)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Review Row

struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
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
        let components = NSColor(self).cgColor.components ?? [0, 0, 0]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

#Preview {
    CourseBuilderView()
}
