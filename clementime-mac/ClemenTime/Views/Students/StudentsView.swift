//
//  StudentsView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI
import UniformTypeIdentifiers

struct StudentsView: View {
    let course: Course
    @StateObject private var viewModel: StudentsViewModel
    @State private var showImportPicker = false
    @State private var showAddStudent = false
    @State private var selectedStudent: Student.ID?

    init(course: Course) {
        self.course = course
        self._viewModel = StateObject(wrappedValue: StudentsViewModel(
            course: course,
            studentRepository: PersistenceController.shared.studentRepository,
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
                ProgressView("Loading students...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredStudents.isEmpty {
                emptyState
            } else {
                studentsTable
            }
        }
        .task {
            await viewModel.loadStudents()
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            Task {
                switch result {
                case .success(let files):
                    if let fileURL = files.first {
                        await viewModel.importRoster(from: fileURL)
                    }
                case .failure(let error):
                    viewModel.error = "Failed to import file: \(error.localizedDescription)"
                }
            }
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
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search students...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .frame(width: 300)

            Spacer()

            // Stats
            statsView

            Spacer()

            // Actions
            Button(action: {
                showImportPicker = true
            }) {
                Label("Import Roster", systemImage: "square.and.arrow.down")
            }
            .disabled(!viewModel.canManageStudents)

            Button(action: {
                showAddStudent = true
            }) {
                Label("Add Student", systemImage: "plus")
            }
            .disabled(!viewModel.canManageStudents)
            .buttonStyle(.borderedProminent)

            if viewModel.isImporting {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
    }

    private var statsView: some View {
        HStack(spacing: 20) {
            StatBadge(
                label: "Total",
                value: viewModel.totalStudentsCount,
                color: .blue
            )

            StatBadge(
                label: "Active",
                value: viewModel.activeStudentsCount,
                color: .green
            )
        }
    }

    // MARK: - Students Table

    private var studentsTable: some View {
        Table(viewModel.filteredStudents, selection: $selectedStudent) {
            TableColumn("Name") { student in
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.fullName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(student.sisUserId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .width(min: 150, ideal: 250)

            TableColumn("Email") { student in
                Text(student.email)
                    .font(.body)
            }
            .width(min: 150, ideal: 250)

            TableColumn("Section") { student in
                // TODO: Fetch section name from repository
                Text("Section \(student.sectionId.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Cohort") { student in
                // TODO: Fetch cohort name from repository
                Text("Cohort \(student.cohortId.uuidString.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Status") { student in
                if student.isActive {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                } else {
                    Label("Inactive", systemImage: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .width(min: 80, ideal: 100)

            TableColumn("Actions") { student in
                HStack(spacing: 8) {
                    Button(action: {
                        selectedStudent = student.id
                        // TODO: Show edit sheet
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canManageStudents)
                    .help("Edit student")

                    Button(action: {
                        Task {
                            await viewModel.deleteStudent(student)
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canManageStudents)
                    .help("Delete student")
                }
            }
            .width(min: 60, ideal: 80)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Students")
                .font(.title2)
                .fontWeight(.semibold)

            if viewModel.searchQuery.isEmpty {
                Text("Import a roster CSV file to add students to this course")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                if viewModel.canManageStudents {
                    Button(action: {
                        showImportPicker = true
                    }) {
                        Label("Import Roster", systemImage: "square.and.arrow.down")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Text("No students match '\(viewModel.searchQuery)'")
                    .font(.body)
                    .foregroundColor(.secondary)

                Button("Clear Search") {
                    viewModel.searchQuery = ""
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    StudentsView(course: Course(
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
