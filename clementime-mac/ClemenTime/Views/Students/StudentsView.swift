//
//  StudentsView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Undo Helper

class UndoHelper: NSObject {
    static let shared = UndoHelper()
}

struct StudentsView: View {
    let course: Course
    @StateObject private var viewModel: StudentsViewModel
    @Environment(\.undoManager) var undoManager
    @State private var showImportPicker = false
    @State private var showAddStudent = false
    @State private var showEditStudent = false
    @State private var selectedStudent: Student.ID?
    @State private var showPDFExportSheet = false
    @State private var studentToDelete: Student?
    @State private var showDeleteConfirmation = false
    @State private var showImportOptionsSheet = false
    @State private var pendingImportURL: URL?
    @State private var randomlyAssignCohorts = false
    @State private var clearExistingStudents = false
    @State private var showReassignConfirmation = false
    @State private var sortOrder = [KeyPathComparator(\Student.fullName)]

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
                        pendingImportURL = fileURL
                        showImportOptionsSheet = true
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
        .sheet(isPresented: $showPDFExportSheet) {
            RosterExportSheet(
                course: course,
                students: viewModel.students,
                sections: viewModel.sections,
                cohorts: viewModel.cohorts,
                examSlots: viewModel.examSlots
            )
        }
        .alert("Delete Student?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                studentToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let student = studentToDelete {
                    Task {
                        await deleteStudentWithUndo(student)
                        studentToDelete = nil
                    }
                }
            }
        } message: {
            if let student = studentToDelete {
                Text("Are you sure you want to delete \(student.fullName)? Press Cmd+Z to undo.")
            }
        }
        .sheet(isPresented: $showAddStudent) {
            StudentEditorView(courseId: course.id, sectionId: nil, student: nil) { newStudent in
                Task {
                    await createStudent(newStudent)
                }
            }
        }
        .sheet(isPresented: $showEditStudent) {
            if let studentId = selectedStudent,
               let student = viewModel.students.first(where: { $0.id == studentId }) {
                StudentEditorView(courseId: course.id, sectionId: nil, student: student) { updatedStudent in
                    Task {
                        await updateStudent(updatedStudent)
                    }
                }
            }
        }
        .sheet(isPresented: $showImportOptionsSheet) {
            ImportOptionsSheet(
                randomlyAssignCohorts: $randomlyAssignCohorts,
                clearExistingStudents: $clearExistingStudents,
                csvURL: pendingImportURL,
                onImport: {
                    showImportOptionsSheet = false
                    if let url = pendingImportURL {
                        Task {
                            await viewModel.importRoster(from: url, randomlyAssignCohorts: randomlyAssignCohorts, clearExistingStudents: clearExistingStudents)
                        }
                    }
                },
                onCancel: {
                    showImportOptionsSheet = false
                    pendingImportURL = nil
                    randomlyAssignCohorts = false
                    clearExistingStudents = false
                }
            )
        }
        .alert("Shuffle Cohorts?", isPresented: $showReassignConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Shuffle") {
                Task {
                    await viewModel.randomlyReassignCohorts()
                }
            }
        } message: {
            Text("This will randomly reassign all students to cohorts with even distribution. This action cannot be undone.")
        }
    }

    // MARK: - Student Operations

    private func createStudent(_ student: Student) async {
        do {
            let studentRepository = PersistenceController.shared.studentRepository
            _ = try await studentRepository.createStudent(student)
            await viewModel.loadStudents()
            viewModel.successMessage = "Student created successfully"
        } catch {
            viewModel.error = "Failed to create student: \(error.localizedDescription)"
        }
    }

    private func updateStudent(_ student: Student) async {
        do {
            let studentRepository = PersistenceController.shared.studentRepository
            try await studentRepository.updateStudent(student)
            await viewModel.loadStudents()
            viewModel.successMessage = "Student updated successfully"
        } catch {
            viewModel.error = "Failed to update student: \(error.localizedDescription)"
        }
    }

    private func deleteStudentWithUndo(_ student: Student) async {
        // Perform deletion
        await viewModel.deleteStudent(student)

        // Register undo operation (capture the deleted student)
        let deletedStudent = student
        let repository = PersistenceController.shared.studentRepository
        let vm = viewModel
        let helper = UndoHelper.shared

        undoManager?.registerUndo(withTarget: helper) { _ in
            Task { @MainActor in
                do {
                    // Restore the student
                    _ = try await repository.createStudent(deletedStudent)
                    await vm.loadStudents()
                    vm.successMessage = "Student restored: \(deletedStudent.fullName)"
                } catch {
                    vm.error = "Failed to restore student: \(error.localizedDescription)"
                }
            }
        }
        undoManager?.setActionName("Delete Student")
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
                showReassignConfirmation = true
            }) {
                Label("Shuffle Cohorts", systemImage: "shuffle")
            }
            .disabled(!viewModel.canManageStudents || viewModel.students.isEmpty || viewModel.cohorts.count < 2)
            .buttonStyle(.bordered)
            .help("Randomly reassign all students to cohorts with even distribution")

            Button(action: {
                showPDFExportSheet = true
            }) {
                Label("Export Roster PDF", systemImage: "doc.richtext")
            }
            .disabled(viewModel.students.isEmpty)
            .buttonStyle(.bordered)
            .help("Export student roster as PDF")

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

            StatBadge(
                label: "Inactive",
                value: viewModel.inactiveStudentsCount,
                color: .gray
            )
        }
    }

    // MARK: - Students Table

    private var sortedStudents: [Student] {
        var students = viewModel.filteredStudents

        for comparator in sortOrder {
            if comparator.order == .forward {
                students.sort { student1, student2 in
                    compareSortOrder(student1, student2, keyPath: comparator.keyPath)
                }
            } else {
                students.sort { student1, student2 in
                    compareSortOrder(student2, student1, keyPath: comparator.keyPath)
                }
            }
        }

        return students
    }

    private func compareSortOrder(_ student1: Student, _ student2: Student, keyPath: PartialKeyPath<Student>) -> Bool {
        switch keyPath {
        case \Student.fullName:
            return student1.fullName.localizedCompare(student2.fullName) == .orderedAscending
        case \Student.email:
            return student1.email.localizedCompare(student2.email) == .orderedAscending
        case \Student.statusSortValue:
            return student1.statusSortValue.localizedCompare(student2.statusSortValue) == .orderedAscending
        case \Student.sectionId:
            let section1 = viewModel.sectionName(for: student1.sectionId)
            let section2 = viewModel.sectionName(for: student2.sectionId)
            return section1.localizedCompare(section2) == .orderedAscending
        case \Student.cohortId:
            // Sort by custom cohort only (exclude "All Students")
            let cohort1 = viewModel.cohorts.first(where: { $0.id == student1.cohortId })
            let cohort2 = viewModel.cohorts.first(where: { $0.id == student2.cohortId })

            let cohort1Name: String
            if let c1 = cohort1, !c1.isDefault {
                cohort1Name = c1.name
            } else {
                cohort1Name = "" // Sort "All Students" cohort to beginning
            }

            let cohort2Name: String
            if let c2 = cohort2, !c2.isDefault {
                cohort2Name = c2.name
            } else {
                cohort2Name = "" // Sort "All Students" cohort to beginning
            }

            return cohort1Name.localizedCompare(cohort2Name) == .orderedAscending
        case \Student.isActive:
            // Active (true) comes before Inactive (false)
            if student1.isActive == student2.isActive {
                return false
            }
            return student1.isActive
        default:
            print("⚠️ Unknown sort keypath: \(keyPath)")
            return false
        }
    }

    private var studentsTable: some View {
        Table(sortedStudents, selection: $selectedStudent, sortOrder: $sortOrder) {
            TableColumn("Name", value: \Student.fullName) { student in
                VStack(alignment: .leading, spacing: 2) {
                    Text(student.fullName)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(student.sisUserId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .opacity(student.isActive ? 1.0 : 0.5)
            }
            .width(min: 150, ideal: 250)

            TableColumn("Email", value: \Student.email) { student in
                Text(student.email)
                    .font(.body)
                    .opacity(student.isActive ? 1.0 : 0.5)
            }
            .width(min: 150, ideal: 250)

            TableColumn("Section", value: \Student.sectionId) { student in
                HStack(spacing: 6) {
                    if student.hasUnmatchedSection, let unmatchedCode = student.unmatchedSectionCode {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption2)
                            Text(unmatchedCode)
                                .font(.caption)
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                        }
                        .help("Section '\(unmatchedCode)' not found in course")
                    } else {
                        Text(viewModel.sectionName(for: student.sectionId))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .opacity(student.isActive ? 1.0 : 0.5)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Cohort", value: \Student.cohortId) { student in
                VStack(alignment: .leading, spacing: 2) {
                    // Always show "All Students" cohort first
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 6, height: 6)
                        Text("All Students")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Show assigned custom cohort (only if it's not the default "All Students" cohort)
                    if let assignedCohort = viewModel.cohorts.first(where: { $0.id == student.cohortId }) {
                        if !assignedCohort.isDefault {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: assignedCohort.colorHex) ?? .blue)
                                    .frame(width: 6, height: 6)
                                Text(assignedCohort.name)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
                .opacity(student.isActive ? 1.0 : 0.5)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Status", value: \Student.statusSortValue) { student in
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
                        showEditStudent = true
                    }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canManageStudents)
                    .help("Edit student")

                    Button(action: {
                        studentToDelete = student
                        showDeleteConfirmation = true
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
        .contextMenu(forSelectionType: Student.ID.self) { studentIds in
            if studentIds.count == 1, let studentId = studentIds.first,
               let student = viewModel.students.first(where: { $0.id == studentId }) {
                // Edit
                Button(action: {
                    selectedStudent = student.id
                    showEditStudent = true
                }) {
                    Label("Edit Student", systemImage: "pencil")
                }
                .disabled(!viewModel.canManageStudents)

                Divider()

                // Activate/Deactivate
                if student.isActive {
                    Button(action: {
                        Task {
                            await toggleStudentActiveStatus(student)
                        }
                    }) {
                        Label("Deactivate Student", systemImage: "pause.circle")
                    }
                    .disabled(!viewModel.canManageStudents)
                } else {
                    Button(action: {
                        Task {
                            await toggleStudentActiveStatus(student)
                        }
                    }) {
                        Label("Reactivate Student", systemImage: "play.circle")
                    }
                    .disabled(!viewModel.canManageStudents)
                }

                Divider()

                // Delete
                Button(action: {
                    studentToDelete = student
                    showDeleteConfirmation = true
                }) {
                    Label("Delete Student", systemImage: "trash")
                }
                .disabled(!viewModel.canManageStudents)
            }
        }
    }

    // MARK: - Student Actions

    private func toggleStudentActiveStatus(_ student: Student) async {
        do {
            var updatedStudent = student
            updatedStudent.isActive = !student.isActive

            let studentRepository = PersistenceController.shared.studentRepository
            try await studentRepository.updateStudent(updatedStudent)
            await viewModel.loadStudents()

            viewModel.successMessage = updatedStudent.isActive ? "Student reactivated" : "Student deactivated"
        } catch {
            viewModel.error = "Failed to update student: \(error.localizedDescription)"
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

// MARK: - Import Options Sheet

struct ImportOptionsSheet: View {
    @Binding var randomlyAssignCohorts: Bool
    @Binding var clearExistingStudents: Bool
    let csvURL: URL?
    let onImport: () -> Void
    let onCancel: () -> Void

    @State private var sectionPreviewExamples: [SectionParseExample] = []

    struct SectionParseExample {
        let rawValue: String
        let parsedSections: [String]
        let selectedSection: String?
        let hasWarning: Bool
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    Toggle(isOn: $clearExistingStudents) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Clear existing students before import")
                                .fontWeight(.medium)
                            Text("Remove all current students and import fresh data. Use this when you want to replace the entire roster.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.red)

                    Toggle(isOn: $randomlyAssignCohorts) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Randomly assign students to cohorts")
                                .fontWeight(.medium)
                            Text("Distribute students evenly across all cohorts. If disabled, students will be assigned to cohorts based on their section.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Import Options")
                        .font(.headline)
                }

                if !sectionPreviewExamples.isEmpty {
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The section field will be parsed as follows:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(sectionPreviewExamples.prefix(3).enumerated()), id: \.offset) { index, example in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Input:")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text(example.rawValue)
                                            .font(.caption2.monospaced())
                                            .foregroundColor(.primary)
                                    }

                                    HStack {
                                        Text("Parsed:")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        HStack(spacing: 4) {
                                            ForEach(Array(example.parsedSections.enumerated()), id: \.offset) { sectionIndex, section in
                                                Text(section)
                                                    .font(.caption2.monospaced())
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        example.selectedSection == section
                                                            ? Color.green.opacity(0.2)
                                                            : Color.gray.opacity(0.1)
                                                    )
                                                    .cornerRadius(4)
                                                    .overlay(
                                                        example.selectedSection == section
                                                            ? RoundedRectangle(cornerRadius: 4)
                                                                .stroke(Color.green, lineWidth: 1)
                                                            : nil
                                                    )
                                            }
                                        }
                                    }

                                    if let selected = example.selectedSection {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption2)
                                            Text("Will use: \(selected)")
                                                .font(.caption2)
                                                .foregroundColor(.green)
                                        }
                                    }

                                    if example.hasWarning {
                                        HStack {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                                .font(.caption2)
                                            Text("More than 2 sections - will flag for manual review")
                                                .font(.caption2)
                                                .foregroundColor(.orange)
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)

                                if index < min(2, sectionPreviewExamples.count - 1) {
                                    Divider()
                                }
                            }

                            Text("Logic: Uses 2nd section if exactly 2 sections are found, otherwise uses the single section or flags for review.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } header: {
                        Text("Section Parsing Preview")
                            .font(.headline)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Import Roster")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .task {
                await loadSectionPreview()
            }
        }
        .frame(width: 650, height: 550)
    }

    private func loadSectionPreview() async {
        guard let url = csvURL else {
            print("[Preview] No CSV URL provided")
            return
        }

        guard url.startAccessingSecurityScopedResource() else {
            print("[Preview] Failed to access security-scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            let lines = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count > 1 else {
                print("[Preview] CSV has no data rows")
                return
            }

            // Parse header - handle both comma and quoted comma
            let headerLine = lines[0]
            let header = CSVParser.parseCSVLine(headerLine)

            print("[Preview] CSV headers: \(header)")

            // Find section column - more flexible matching
            let sectionAliases = ["section", "section_code", "section_id", "section name"]
            let sectionIndex = header.firstIndex { headerCol in
                let normalizedHeader = headerCol.lowercased().trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                return sectionAliases.contains { alias in
                    let normalizedAlias = alias.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
                    return normalizedHeader.contains(normalizedAlias)
                }
            }

            guard let sectionIndex = sectionIndex else {
                print("[Preview] Could not find section column. Headers: \(header)")
                return
            }

            print("[Preview] Found section column at index \(sectionIndex): \(header[sectionIndex])")

            // Parse first few rows to show examples
            var examples: [SectionParseExample] = []
            var seenPatterns: Set<String> = []

            for line in lines.dropFirst().prefix(20) {
                let fields = CSVParser.parseCSVLine(line)

                guard fields.count > sectionIndex else { continue }

                let sectionField = fields[sectionIndex]

                // Skip if we've already seen this pattern
                if seenPatterns.contains(sectionField) { continue }
                seenPatterns.insert(sectionField)

                let sections = sectionField
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                let selectedSection: String?
                let hasWarning: Bool

                if sections.count == 1 {
                    selectedSection = sections[0]
                    hasWarning = false
                } else if sections.count == 2 {
                    selectedSection = sections[1]  // Use the second one
                    hasWarning = false
                } else if sections.count > 2 {
                    selectedSection = sections.last
                    hasWarning = true
                } else {
                    selectedSection = nil
                    hasWarning = true
                }

                examples.append(SectionParseExample(
                    rawValue: sectionField,
                    parsedSections: sections,
                    selectedSection: selectedSection,
                    hasWarning: hasWarning
                ))

                // Limit to 3 unique patterns
                if examples.count >= 3 { break }
            }

            sectionPreviewExamples = examples
            print("[Preview] Loaded \(examples.count) section preview examples")
        } catch {
            print("[Preview] Error loading preview: \(error.localizedDescription)")
        }
    }
}

#Preview {
    StudentsView(course: Course(
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
