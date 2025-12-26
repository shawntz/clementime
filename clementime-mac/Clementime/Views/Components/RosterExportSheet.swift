//
//  RosterExportSheet.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct RosterExportSheet: View {
    @Environment(\.dismiss) var dismiss

    let course: Course
    let students: [Student]
    let sections: [Section]
    let cohorts: [Cohort]
    let examSlots: [ExamSlot]

    @State private var options = RosterExportOptions()
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // Layout Style
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Layout Style")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Picker("", selection: $options.layoutStyle) {
                                ForEach(PDFLayoutStyle.allCases) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(options.layoutStyle.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    // Filters
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 12) {
                            if !sections.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Section Filter")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Picker("", selection: $options.filterBySection) {
                                        Text("All Sections").tag(nil as UUID?)
                                        ForEach(sections, id: \.id) { section in
                                            Text(section.name).tag(section.id as UUID?)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }

                            if !cohorts.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cohort Filter")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Picker("", selection: $options.filterByCohort) {
                                        Text("All Cohorts").tag(nil as UUID?)
                                        ForEach(cohorts, id: \.id) { cohort in
                                            HStack {
                                                Circle()
                                                    .fill(Color(hex: cohort.colorHex) ?? .blue)
                                                    .frame(width: 10, height: 10)
                                                Text(cohort.name)
                                            }
                                            .tag(cohort.id as UUID?)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Filters")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Sort Options
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sort By")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Picker("", selection: $options.sortBy) {
                                ForEach(RosterExportOptions.RosterSortOption.allCases) { sortOption in
                                    Text(sortOption.rawValue).tag(sortOption)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Sorting")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Display Options
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Include Email", isOn: $options.includeEmail)
                            Toggle("Include Section", isOn: $options.includeSection)
                            Toggle("Include Cohort", isOn: $options.includeCohort)
                            Toggle("Include Exam Slot", isOn: $options.includeExamSlot)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Display Options")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                .formStyle(.grouped)

                // Preview info at bottom
                VStack(spacing: 8) {
                    Divider()
                    let filteredCount = students.filter { options.shouldInclude($0, cohorts: cohorts) }.count
                    HStack {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    HStack {
                        Text("Filtered Students:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(filteredCount) of \(students.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .navigationTitle("Export Course Roster PDF")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        exportPDF()
                    } label: {
                        if isExporting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Exporting...")
                            }
                        } else {
                            Text("Export")
                        }
                    }
                    .disabled(isExporting)
                    .buttonStyle(.borderedProminent)
                }
            }
            .alert("Export Error", isPresented: .constant(exportError != nil)) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 600, idealHeight: 650)
    }

    private func exportPDF() {
        isExporting = true

        Task {
            do {
                // Generate PDF
                guard let pdfData = RosterPDFGenerator.generatePDF(
                    course: course,
                    students: students,
                    sections: sections,
                    cohorts: cohorts,
                    examSlots: examSlots,
                    options: options
                ) else {
                    throw PDFExportError.generationFailed
                }

                guard let pdfDocument = PDFDocument(data: pdfData) else {
                    throw PDFExportError.generationFailed
                }

                // Show save panel
                await MainActor.run {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.pdf]
                    savePanel.nameFieldStringValue = "\(course.name.replacingOccurrences(of: " ", with: "_"))_Roster.pdf"
                    savePanel.message = "Export course roster as PDF"
                    savePanel.canCreateDirectories = true

                    savePanel.begin { response in
                        if response == .OK, let url = savePanel.url {
                            if pdfDocument.write(to: url) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                                dismiss()
                            } else {
                                exportError = "Failed to write PDF to file"
                            }
                        }
                        isExporting = false
                    }
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

#Preview {
    RosterExportSheet(
        course: Course(
            id: UUID(),
            name: "PSYCH 10",
            term: "Fall 2025",
            quarterStartDate: Date(),
            quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(),
            totalExams: 5,
            isActive: true,
            createdBy: UUID(),
            settings: CourseSettings()
        ),
        students: [],
        sections: [],
        cohorts: [],
        examSlots: []
    )
}
