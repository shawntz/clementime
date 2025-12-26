//
//  ScheduleExportSheet.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ScheduleExportSheet: View {
    @Environment(\.dismiss) var dismiss

    let course: Course
    let examNumber: Int
    let slots: [ExamSlot]
    let students: [Student]
    let sections: [Section]

    @State private var options = ScheduleExportOptions()
    @State private var exportMode: ExportMode = .bulkBySection
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var exportSuccessMessage: String?

    enum ExportMode: String, CaseIterable, Identifiable {
        case bulkBySection = "One PDF per Section"
        case single = "Single PDF"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .bulkBySection:
                return "Export separate PDFs for each section (TAs can distribute to students)"
            case .single:
                return "Export a single PDF with selected filters"
            }
        }
    }

    /// Sanitize a string to be safe for use in filenames
    private func sanitizeFilename(_ name: String) -> String {
        return name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "*", with: "-")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "\"", with: "-")
            .replacingOccurrences(of: "<", with: "-")
            .replacingOccurrences(of: ">", with: "-")
            .replacingOccurrences(of: "|", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Get an available filename by appending (1), (2), etc. if file exists
    private func getAvailableFileURL(baseURL: URL) -> URL {
        var url = baseURL
        var counter = 1

        let directory = url.deletingLastPathComponent()
        let filename = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        while FileManager.default.fileExists(atPath: url.path) {
            let newFilename = "\(filename) (\(counter)).\(ext)"
            url = directory.appendingPathComponent(newFilename)
            counter += 1
        }

        return url
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // Export Mode
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Export Mode")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Picker("", selection: $exportMode) {
                                ForEach(ExportMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()

                            Text(exportMode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

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
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Status Filter")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $options.filterByStatus) {
                                    ForEach(ScheduleExportOptions.ScheduleStatusFilter.allCases) { filter in
                                        Text(filter.rawValue).tag(filter)
                                    }
                                }
                                .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Locked Filter")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $options.filterByLocked) {
                                    ForEach(ScheduleExportOptions.LockedFilter.allCases) { filter in
                                        Text(filter.rawValue).tag(filter)
                                    }
                                }
                                .labelsHidden()
                            }

                            if !sections.isEmpty && exportMode == .single {
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
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Filters")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Display Options
                    SwiftUI.Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Include Logo", isOn: $options.includeLogo)
                            Toggle("Include Statistics", isOn: $options.includeStatistics)
                            Toggle("Include Notes Column", isOn: $options.includeNotes)
                            Toggle("Group by Date", isOn: $options.groupByDate)
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
                    let filteredCount = slots.filter { options.shouldInclude($0) }.count
                    HStack {
                        Text("Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    HStack {
                        Text("Filtered Slots:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(filteredCount) of \(slots.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .navigationTitle("Export Exam \(examNumber) Schedule")
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
            .alert("Export Successful", isPresented: .constant(exportSuccessMessage != nil)) {
                Button("OK") {
                    exportSuccessMessage = nil
                    dismiss()
                }
            } message: {
                if let message = exportSuccessMessage {
                    Text(message)
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 550, minHeight: 600, idealHeight: 650)
    }

    private func exportPDF() {
        isExporting = true

        Task {
            do {
                let pdfGenerator = SchedulePDFGenerator()

                switch exportMode {
                case .single:
                    try await exportSinglePDF(generator: pdfGenerator)
                case .bulkBySection:
                    try await exportBulkPDFs(generator: pdfGenerator)
                }
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }

    private func exportSinglePDF(generator: SchedulePDFGenerator) async throws {
        // Generate PDF
        guard let pdfDocument = generator.generateSchedulePDF(
            course: course,
            examNumber: examNumber,
            slots: slots,
            students: students,
            sections: sections,
            options: options
        ) else {
            throw PDFExportError.generationFailed
        }

        // Show save panel
        await MainActor.run {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.pdf]
            savePanel.nameFieldStringValue = "\(sanitizeFilename(course.name))_Exam_\(examNumber)_Schedule.pdf"
            savePanel.message = "Export exam schedule as PDF"
            savePanel.canCreateDirectories = true

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    // Remove existing file if present (user already confirmed overwrite via save panel)
                    if FileManager.default.fileExists(atPath: url.path) {
                        try? FileManager.default.removeItem(at: url)
                    }

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
    }

    private func exportBulkPDFs(generator: SchedulePDFGenerator) async throws {
        // Generate PDFs for all sections
        let sectionPDFs = generator.generateSectionPDFs(
            course: course,
            examNumber: examNumber,
            slots: slots,
            students: students,
            sections: sections,
            baseOptions: options
        )

        guard !sectionPDFs.isEmpty else {
            throw PDFExportError.generationFailed
        }

        // Show directory chooser
        await MainActor.run {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.message = "Choose a folder to save section PDFs"
            openPanel.prompt = "Save Here"

            openPanel.begin { response in
                if response == .OK, let directoryURL = openPanel.url {
                    var savedURLs: [URL] = []
                    var failedSections: [String] = []
                    var emptySections: [String] = []

                    for (section, pdf) in sectionPDFs {
                        let filename = "\(sanitizeFilename(course.name))_Exam_\(examNumber)_\(sanitizeFilename(section.name)).pdf"
                        let baseURL = directoryURL.appendingPathComponent(filename)
                        let fileURL = getAvailableFileURL(baseURL: baseURL)

                        if pdf.write(to: fileURL) {
                            savedURLs.append(fileURL)

                            // Check if this section had any slots
                            let sectionSlots = slots.filter { $0.sectionId == section.id }
                            if sectionSlots.isEmpty {
                                emptySections.append(section.name)
                            }
                        } else {
                            failedSections.append(section.name)
                        }
                    }

                    // Show results
                    if failedSections.isEmpty {
                        var message = "Successfully exported \(savedURLs.count) PDF(s)"
                        if !emptySections.isEmpty {
                            message += "\n\nNote: The following sections have no scheduled students:\n\(emptySections.joined(separator: ", "))"
                        }
                        exportSuccessMessage = message
                        NSWorkspace.shared.activateFileViewerSelecting(savedURLs)
                    } else {
                        exportError = "Failed to write PDFs for sections: \(failedSections.joined(separator: ", "))"
                    }
                }
                isExporting = false
            }
        }
    }
}

#Preview {
    ScheduleExportSheet(
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
        examNumber: 1,
        slots: [],
        students: [],
        sections: []
    )
}
