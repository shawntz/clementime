//
//  CourseSettingsView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

struct CourseSettingsView: View {
    let course: Course
    @State private var showInviteSheet = false

    var body: some View {
        Form {
            // Basic Info Section
            SwiftUI.Section("Course Information") {
                LabeledContent("Name", value: course.name)
                LabeledContent("Term", value: course.term)
                LabeledContent("Quarter Start", value: course.quarterStartDate, format: .dateTime.day().month().year())
                LabeledContent("Exam Day", value: course.examDay.rawValue.capitalized)
                LabeledContent("Total Exams", value: "\(course.totalExams)")
            }

            // Exam Times Section
            SwiftUI.Section("Exam Times") {
                LabeledContent("Start Time", value: course.settings.examStartTime.formatted)
                LabeledContent("End Time", value: course.settings.examEndTime.formatted)
                LabeledContent("Duration", value: "\(course.settings.examDurationMinutes) minutes")
                LabeledContent("Buffer Time", value: "\(course.settings.examBufferMinutes) minutes")
            }

            // Scheduling Options
            SwiftUI.Section("Scheduling") {
                LabeledContent("Balanced TA Scheduling") {
                    Text(course.settings.balancedTAScheduling ? "Enabled" : "Disabled")
                        .foregroundColor(course.settings.balancedTAScheduling ? .green : .secondary)
                }
            }

            // Collaboration Section
            SwiftUI.Section("Collaboration") {
                collaboratorsView

                Button(action: {
                    showInviteSheet = true
                }) {
                    Label("Invite TA", systemImage: "person.badge.plus")
                }
                .buttonStyle(.borderless)
            }

            // Danger Zone
            SwiftUI.Section("Danger Zone") {
                Button(role: .destructive, action: {
                    // TODO: Implement archive course
                }) {
                    Label("Archive Course", systemImage: "archivebox")
                }

                Button(role: .destructive, action: {
                    // TODO: Implement delete course
                }) {
                    Label("Delete Course", systemImage: "trash")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showInviteSheet) {
            InviteCollaboratorView(course: course)
        }
    }

    private var collaboratorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Teaching Assistants")
                .font(.caption)
                .foregroundColor(.secondary)

            // TODO: Load actual collaborators from repository
            Text("No collaborators yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Invite Collaborator View

struct InviteCollaboratorView: View {
    let course: Course
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var role: UserRole = .ta
    @State private var selectedPermissions: Set<PermissionType> = []
    @State private var isInviting = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Collaborator Information") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                SwiftUI.Section("Role") {
                    Picker("Role", selection: $role) {
                        Text("Admin").tag(UserRole.admin)
                        Text("TA").tag(UserRole.ta)
                    }
                    .pickerStyle(.segmented)
                }

                if role == .ta {
                    SwiftUI.Section("Permissions") {
                        ForEach(PermissionType.allCases, id: \.self) { permission in
                            Toggle(permission.displayName, isOn: Binding(
                                get: { selectedPermissions.contains(permission) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedPermissions.insert(permission)
                                    } else {
                                        selectedPermissions.remove(permission)
                                    }
                                }
                            ))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Invite Collaborator")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send Invitation") {
                        sendInvitation()
                    }
                    .disabled(!isValid || isInviting)
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    errorMessage = nil
                    showErrorAlert = false
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
        .frame(width: 500, height: 600)
    }

    private var isValid: Bool {
        !email.isEmpty && email.contains("@") &&
        !firstName.isEmpty &&
        !lastName.isEmpty
    }

    private func sendInvitation() {
        isInviting = true
        // TODO: Implement invitation
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isInviting = false
            dismiss()
        }
    }
}

#Preview {
    CourseSettingsView(course: Course(
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
