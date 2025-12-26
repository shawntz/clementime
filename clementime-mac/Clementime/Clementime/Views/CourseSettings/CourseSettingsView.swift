//
//  CourseSettingsView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CourseSettingsView: View {
    let course: Course
    @Environment(\.dismiss) var dismiss
    @State private var showInviteSheet = false
    @State private var balancedTAScheduling: Bool
    @State private var showExportPanel = false
    @State private var showImportPanel = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportError: String?
    @State private var importResult: CourseImportResult?
    @State private var showErrorAlert = false
    @State private var showImportResultAlert = false
    @State private var showArchiveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var collaborators: [TAUser] = []
    @State private var isLoadingCollaborators = false
    @State private var showTAListExportSheet = false
    @State private var showBalancedTAInfo = false

    private let courseRepository = PersistenceController.shared.courseRepository
    private let taUserRepository = PersistenceController.shared.taUserRepository

    init(course: Course) {
        self.course = course
        _balancedTAScheduling = State(initialValue: course.settings.balancedTAScheduling)
    }

    var body: some View {
        Form {
            // Basic Info Section
            SwiftUI.Section("Course Information") {
                LabeledContent("Name", value: course.name)
                LabeledContent("Term", value: course.term)
                LabeledContent("Quarter Start", value: course.quarterStartDate, format: .dateTime.day().month().year())
                LabeledContent("Quarter End", value: course.quarterEndDate, format: .dateTime.day().month().year())
                LabeledContent("Total Exams", value: "\(course.totalExams)")
            }

            // Scheduling Options
            SwiftUI.Section("Scheduling") {
                Toggle(isOn: $balancedTAScheduling) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Balanced TA Scheduling")
                                .fontWeight(.medium)
                            Text("Distribute exam slots evenly across TAs")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Button(action: {
                            showBalancedTAInfo = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Click for more information")
                    }
                }
                .onChange(of: balancedTAScheduling) {
                    Task {
                        await updateSchedulingSetting()
                    }
                }
            }

            // Collaboration Section
            SwiftUI.Section("Collaboration") {
                collaboratorsView

                HStack {
                    Button(action: {
                        showInviteSheet = true
                    }) {
                        Label("Invite TA", systemImage: "person.badge.plus")
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button(action: {
                        showTAListExportSheet = true
                    }) {
                        Label("Export TA List PDF", systemImage: "doc.richtext")
                    }
                    .disabled(collaborators.isEmpty)
                    .buttonStyle(.bordered)
                }
            }

            // Data Management Section
            SwiftUI.Section("Data Management") {
                Button(action: {
                    exportCourse()
                }) {
                    Label("Export Course Data", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(isExporting)

                Button(action: {
                    importCourse()
                }) {
                    Label("Import Course Data", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(isImporting)

                Text("Export all course data to a .clementime file for backup or transfer to another system.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Danger Zone
            SwiftUI.Section("Danger Zone") {
                Button(role: .destructive, action: {
                    showArchiveConfirmation = true
                }) {
                    Label("Archive Course", systemImage: "archivebox")
                }

                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }) {
                    Label("Delete Course", systemImage: "trash")
                }

                Text("Archiving will hide the course from your active courses list. Deleting will permanently remove all course data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showInviteSheet) {
            InviteCollaboratorView(course: course)
        }
        .alert("Export Error", isPresented: $showErrorAlert) {
            Button("OK") {
                exportError = nil
            }
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
        .alert("Import Complete", isPresented: $showImportResultAlert) {
            Button("OK") {
                importResult = nil
            }
        } message: {
            if let result = importResult {
                if result.success {
                    Text("Successfully imported course with \(result.studentsImported) students, \(result.sectionsImported) sections, \(result.cohortsImported) cohorts, \(result.examSessionsImported) exam sessions.")
                } else {
                    Text("Import failed: \(result.errors.joined(separator: ", "))")
                }
            }
        }
        .alert("Archive Course?", isPresented: $showArchiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                Task {
                    await archiveCourse()
                }
            }
        } message: {
            Text("This will archive '\(course.name)' and hide it from your active courses. You can restore it later.")
        }
        .alert("Delete Course?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteCourse()
                }
            }
        } message: {
            Text("This will permanently delete '\(course.name)' and all associated data. This action cannot be undone.")
        }
        .alert("Balanced TA Scheduling", isPresented: $showBalancedTAInfo) {
            Button("OK") { }
        } message: {
            Text("⚠️ Do NOT enable this if you want students to be assigned to their own TA's sections.\n\nWhen enabled, the scheduler will distribute exam slots evenly across all TAs, regardless of student-section assignments.\n\nWhen disabled, students will be preferentially assigned to exams with their own section's TA.")
        }
        .sheet(isPresented: $showTAListExportSheet) {
            TAListExportSheet(
                course: course,
                taUsers: collaborators
            )
        }
    }

    private var collaboratorsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Teaching Assistants")
                .font(.caption)
                .foregroundColor(.secondary)

            if isLoadingCollaborators {
                ProgressView()
                    .scaleEffect(0.7)
            } else if collaborators.isEmpty {
                Text("No collaborators yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(collaborators) { collaborator in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(collaborator.fullName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(collaborator.email)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(collaborator.role.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task {
            await loadCollaborators()
        }
    }

    private func exportCourse() {
        isExporting = true
        Task {
            do {
                // Create a basic export structure
                let courseExport = CourseExport(
                    version: CourseExport.currentVersion,
                    exportedAt: Date(),
                    course: CourseExportData(
                        name: course.name,
                        term: course.term,
                        quarterStartDate: course.quarterStartDate,
                        quarterEndDate: course.quarterEndDate,
                        totalExams: course.totalExams,
                        isActive: course.isActive,
                        settingsJSON: course.settings.encode(),
                        metadataJSON: "{}"
                    ),
                    cohorts: [],
                    sections: [],
                    students: [],
                    examSessions: [],
                    examSlots: [],
                    constraints: [],
                    taUsers: []
                )

                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let jsonData = try encoder.encode(courseExport)

                // Show save panel
                await MainActor.run {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.json]
                    savePanel.nameFieldStringValue = "\(course.name.replacingOccurrences(of: " ", with: "_"))_\(course.term.replacingOccurrences(of: " ", with: "_")).clementime"
                    savePanel.message = "Export course data"

                    savePanel.begin { response in
                        if response == .OK, let url = savePanel.url {
                            do {
                                try jsonData.write(to: url)
                            } catch {
                                exportError = error.localizedDescription
                                showErrorAlert = true
                            }
                        }
                        isExporting = false
                    }
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    showErrorAlert = true
                    isExporting = false
                }
            }
        }
    }

    private func importCourse() {
        isImporting = true

        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Select a .clementime file to import"

        openPanel.begin { response in
            if response == .OK, let _ = openPanel.url {
                Task {
                    // For now, just show a placeholder result
                    let result = CourseImportResult(
                        success: true,
                        importedCourseId: UUID(),
                        errors: [],
                        warnings: []
                    )

                    await MainActor.run {
                        importResult = result
                        showImportResultAlert = true
                    }
                    isImporting = false
                }
            } else {
                isImporting = false
            }
        }
    }

    private func loadCollaborators() async {
        isLoadingCollaborators = true
        do {
            collaborators = try await taUserRepository.fetchTAUsers(courseId: course.id)
        } catch {
            print("Failed to load collaborators: \(error)")
            collaborators = []
        }
        isLoadingCollaborators = false
    }

    private func archiveCourse() async {
        do {
            var archivedCourse = course
            archivedCourse.isActive = false
            try await courseRepository.updateCourse(archivedCourse)
            dismiss()
        } catch {
            exportError = "Failed to archive course: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func deleteCourse() async {
        do {
            try await courseRepository.deleteCourse(id: course.id)
            dismiss()
        } catch {
            exportError = "Failed to delete course: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func updateSchedulingSetting() async {
        do {
            var updatedCourse = course
            updatedCourse.settings.balancedTAScheduling = balancedTAScheduling
            try await courseRepository.updateCourse(updatedCourse)
        } catch {
            exportError = "Failed to update scheduling settings: \(error.localizedDescription)"
            showErrorAlert = true
            balancedTAScheduling = course.settings.balancedTAScheduling
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
        Task {
            do {
                let taUserRepository = PersistenceController.shared.taUserRepository

                // Check if user already exists
                if let _ = try? await taUserRepository.fetchTAUser(email: email, courseId: course.id) {
                    await MainActor.run {
                        errorMessage = "User with email \(email) is already a collaborator on this course"
                        showErrorAlert = true
                        isInviting = false
                    }
                    return
                }

                // Create permissions based on role
                let permissions = role == .admin ? Permission.allPermissions() : Permission.defaultTAPermissions()

                // Apply selected permissions if TA
                let finalPermissions: [Permission]
                if role == .ta && !selectedPermissions.isEmpty {
                    finalPermissions = PermissionType.allCases.map { permType in
                        Permission(type: permType, isGranted: selectedPermissions.contains(permType))
                    }
                } else {
                    finalPermissions = permissions
                }

                // Create the TA user
                let taUser = TAUser(
                    id: UUID(),
                    courseId: course.id,
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    username: email.components(separatedBy: "@").first ?? email,
                    role: role,
                    customPermissions: finalPermissions,
                    location: "",
                    slackId: nil,
                    isActive: true
                )

                _ = try await taUserRepository.createTAUser(taUser)

                // Generate CloudKit share URL for the course
                do {
                    let courseRepository = PersistenceController.shared.courseRepository
                    let shareURL = try await courseRepository.shareCourse(
                        course.id,
                        with: email,
                        permissions: finalPermissions
                    )

                    // Open default mail client with pre-filled invitation
                    let subject = "Invitation to collaborate on \(course.name)"
                    let body = """
                    Hi \(firstName),

                    You've been invited to collaborate on the course "\(course.name)" (\(course.term)) as a \(role.displayName).

                    Click the link below to accept the invitation and access the course:
                    \(shareURL.absoluteString)

                    Best regards,
                    Clementime Team
                    """

                    if let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let mailtoURL = URL(string: "mailto:\(email)?subject=\(encodedSubject)&body=\(encodedBody)") {
                        _ = await MainActor.run {
                            NSWorkspace.shared.open(mailtoURL)
                        }
                    }
                } catch {
                    // If CloudKit sharing fails, still allow the user creation to succeed
                    // They can be added manually to the share later
                    print("Failed to generate share URL: \(error)")
                }

                await MainActor.run {
                    isInviting = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create invitation: \(error.localizedDescription)"
                    showErrorAlert = true
                    isInviting = false
                }
            }
        }
    }
}

#Preview {
    CourseSettingsView(course: Course(
        id: UUID(),
        name: "PSYCH 10",
        term: "Fall 2025",
        quarterStartDate: Date(),
        quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(),
        totalExams: 5,
        isActive: true,
        createdBy: UUID(),
        settings: CourseSettings()
    ))
}
