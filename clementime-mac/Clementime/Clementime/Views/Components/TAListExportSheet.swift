//
//  TAListExportSheet.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct TAListExportSheet: View {
    @Environment(\.dismiss) var dismiss

    let course: Course
    let taUsers: [TAUser]

    @State private var options = TAListExportOptions()
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // Layout Style
                    SwiftUI.Section {
                        Picker("Style", selection: $options.layoutStyle) {
                            ForEach(PDFLayoutStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    } header: {
                        Text("Layout Style")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Filters
                    SwiftUI.Section {
                        Picker("Role Filter", selection: $options.filterByRole) {
                            Text("All Roles").tag(nil as UserRole?)
                            ForEach(UserRole.allCases) { role in
                                Text(role.displayName).tag(role as UserRole?)
                            }
                        }
                    } header: {
                        Text("Filters")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Sort Options
                    SwiftUI.Section {
                        Picker("Sort By", selection: $options.sortBy) {
                            ForEach(TAListExportOptions.TASortOption.allCases) { sortOption in
                                Text(sortOption.rawValue).tag(sortOption)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Sorting")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }

                    // Display Options
                    SwiftUI.Section {
                        Toggle("Include Logo", isOn: $options.includeLogo)
                        Toggle("Include Contact Info", isOn: $options.includeContactInfo)
                        Toggle("Include Permissions", isOn: $options.includePermissions)
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
                    let filteredCount = taUsers.filter { options.shouldInclude($0) }.count
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.secondary)
                        Text("Filtered Collaborators:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(filteredCount) of \(taUsers.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.controlBackgroundColor))
                }
            }
            .navigationTitle("Export TA List")
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
        .frame(minWidth: 500, idealWidth: 550, minHeight: 550, idealHeight: 600)
    }

    private func exportPDF() {
        isExporting = true

        Task {
            do {
                // Generate PDF
                let pdfGenerator = TAListPDFGenerator()
                guard let pdfDocument = pdfGenerator.generateTAListPDF(
                    course: course,
                    taUsers: taUsers,
                    options: options
                ) else {
                    throw PDFExportError.generationFailed
                }

                // Show save panel
                await MainActor.run {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.pdf]
                    savePanel.nameFieldStringValue = "\(course.name.replacingOccurrences(of: " ", with: "_"))_TA_List.pdf"
                    savePanel.message = "Export TA list as PDF"
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
    TAListExportSheet(
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
        taUsers: []
    )
}
