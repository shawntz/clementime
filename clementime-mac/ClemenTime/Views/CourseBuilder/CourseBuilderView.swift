//
//  CourseBuilderView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

struct CourseBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var courseName = ""
    @State private var term = ""
    @State private var courseDescription = ""
    @State private var selectedIcon = "book.fill"
    @State private var isCreating = false
    @State private var errorMessage: String?

    let iconOptions = [
        "book.fill", "graduationcap.fill", "brain.head.profile",
        "function", "chart.bar.fill", "network",
        "atom", "flask.fill", "cross.case.fill",
        "doc.text.fill", "folder.fill", "calendar"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create New Course")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 24) {
                // Icon Picker
                HStack(alignment: .center, spacing: 12) {
                    Text("Icon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Menu {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                HStack {
                                    Image(systemName: icon)
                                    if selectedIcon == icon {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 50, height: 50)

                                Image(systemName: selectedIcon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }

                            Text("Choose Icon")
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Course Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Course Name")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextField("e.g., PSYCH 10 / STATS 60", text: $courseName)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }

                // Term
                VStack(alignment: .leading, spacing: 8) {
                    Text("Term")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextField("e.g., Fall 2025", text: $term)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description (Optional)")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    TextEditor(text: $courseDescription)
                        .font(.body)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.callout)
                        .padding(.vertical, 8)
                }
            }
            .padding(24)

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create Course") {
                    createCourse()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || isCreating)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
    }

    private var isValid: Bool {
        !courseName.isEmpty && !term.isEmpty
    }

    private func createCourse() {
        guard !courseName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a course name"
            return
        }

        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a term"
            return
        }

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

                // Store icon and description in metadata
                var metadata: [String: String] = [
                    "icon": selectedIcon
                ]
                if !courseDescription.isEmpty {
                    metadata["description"] = courseDescription
                }

                let course = Course(
                    id: UUID(),
                    name: courseName.trimmingCharacters(in: .whitespaces),
                    term: term.trimmingCharacters(in: .whitespaces),
                    quarterStartDate: Date(), // Default to today
                    examDay: .friday, // Default to Friday
                    totalExams: 5, // Default to 5 exams
                    isActive: true,
                    createdBy: UUID(), // TODO: Get current user ID
                    settings: settings,
                    metadata: metadata
                )

                // Save course directly via repository (simplified creation - user will configure details later)
                _ = try await PersistenceController.shared.courseRepository.createCourse(course)

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
