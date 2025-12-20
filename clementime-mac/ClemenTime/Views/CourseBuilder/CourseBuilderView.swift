//
//  CourseBuilderView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct CourseBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var courseName = ""
    @State private var term = ""
    @State private var quarterStartDate = Date()
    @State private var examDay: DayOfWeek = .friday
    @State private var totalExams = 5
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Course Information")
                        .font(.title2)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Course Name (e.g., PSYCH 10 / STATS 60)", text: $courseName)
                            .textFieldStyle(.roundedBorder)

                        TextField("Term (e.g., Fall 2025)", text: $term)
                            .textFieldStyle(.roundedBorder)

                        DatePicker("Quarter Start Date", selection: $quarterStartDate, displayedComponents: .date)

                        Picker("Exam Day", selection: $examDay) {
                            ForEach(DayOfWeek.allCases) { day in
                                Text(day.rawValue.capitalized).tag(day)
                            }
                        }
                        .pickerStyle(.menu)

                        Stepper("Total Exams: \(totalExams)", value: $totalExams, in: 1...20)
                    }
                }

                Divider()

                Text("You can configure exam times, cohorts, and scheduling details after creating the course.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Create New Course")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create Course") {
                        createCourse()
                    }
                    .disabled(!isValid || isCreating)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 500, height: 400)
    }

    private var isValid: Bool {
        !courseName.isEmpty && !term.isEmpty
    }

    private func createCourse() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                // Create course with default settings
                let settings = CourseSettings(
                    examStartTime: TimeComponents(hour: 13, minute: 30),
                    examEndTime: TimeComponents(hour: 14, minute: 50),
                    examDurationMinutes: 7,
                    examBufferMinutes: 1,
                    balancedTAScheduling: false
                )

                let course = Course(
                    id: UUID(),
                    name: courseName,
                    term: term,
                    quarterStartDate: quarterStartDate,
                    examDay: examDay,
                    totalExams: totalExams,
                    isActive: true,
                    createdBy: UUID(), // TODO: Get current user ID
                    settings: settings
                )

                // Save course
                let createUseCase = CreateCourseUseCase(
                    courseRepository: PersistenceController.shared.courseRepository,
                    cohortRepository: PersistenceController.shared.cohortRepository,
                    examSessionRepository: PersistenceController.shared.examSessionRepository
                )

                let input = CreateCourseInput(
                    name: course.name,
                    term: course.term,
                    quarterStartDate: course.quarterStartDate,
                    examDay: course.examDay,
                    totalExams: course.totalExams,
                    cohorts: [], // Empty - user will configure later
                    examSessions: [], // Empty - user will configure later
                    settings: settings,
                    createdBy: UUID()
                )

                _ = try await createUseCase.execute(input: input)

                isCreating = false
                dismiss()
            } catch {
                isCreating = false
                errorMessage = "Failed to create course: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    CourseBuilderView()
}
