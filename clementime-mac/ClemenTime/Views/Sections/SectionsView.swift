//
//  SectionsView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import Combine

struct SectionsView: View {
    let course: Course
    @StateObject private var viewModel: SectionsViewModel
    @State private var showAddSection = false
    @State private var selectedSection: Section?

    init(course: Course) {
        self.course = course
        _viewModel = StateObject(wrappedValue: SectionsViewModel(courseId: course.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.sections.isEmpty {
                emptyStateView
            } else {
                sectionsList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showAddSection = true
                }) {
                    Label("Add Section", systemImage: "plus")
                }
            }

            ToolbarItem {
                Button(action: {
                    Task {
                        await viewModel.loadSections()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showAddSection) {
            SectionEditorView(courseId: course.id, section: nil, onSave: { newSection in
                Task {
                    await viewModel.createSection(newSection)
                    showAddSection = false
                }
            })
        }
        .sheet(item: $selectedSection) { section in
            SectionEditorView(courseId: course.id, section: section, onSave: { updatedSection in
                Task {
                    await viewModel.updateSection(updatedSection)
                    selectedSection = nil
                }
            })
        }
        .task {
            await viewModel.loadSections()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            Text("No Sections")
                .font(.title)
                .fontWeight(.semibold)

            Text("Create sections to organize your students and assign TAs")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                showAddSection = true
            }) {
                Label("Create First Section", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private var sectionsList: some View {
        List {
            ForEach(viewModel.sections) { section in
                SectionRow(section: section, onTap: {
                    selectedSection = section
                })
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - Section Row

struct SectionRow: View {
    let section: Section
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Section Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "square.grid.2x2")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.headline)

                    HStack(spacing: 12) {
                        if !section.location.isEmpty {
                            Label(section.location, systemImage: "mappin.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if section.hasAssignedTA {
                            Label("TA Assigned", systemImage: "person.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Label("No TA", systemImage: "person.fill.xmark")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sections ViewModel

class SectionsViewModel: ObservableObject {
    @Published var sections: [Section] = []
    @Published var isLoading = false
    @Published var error: String?

    private let courseId: UUID
    private let sectionRepository: SectionRepository

    init(courseId: UUID, sectionRepository: SectionRepository = PersistenceController.shared.sectionRepository) {
        self.courseId = courseId
        self.sectionRepository = sectionRepository
    }

    @MainActor
    func loadSections() async {
        isLoading = true
        error = nil

        do {
            sections = try await sectionRepository.fetchSections(courseId: courseId)
        } catch {
            self.error = "Failed to load sections: \(error.localizedDescription)"
            print("Error loading sections: \(error)")
        }

        isLoading = false
    }

    @MainActor
    func createSection(_ section: Section) async {
        do {
            _ = try await sectionRepository.createSection(section)
            await loadSections()
        } catch {
            self.error = "Failed to create section: \(error.localizedDescription)"
            print("Error creating section: \(error)")
        }
    }

    @MainActor
    func updateSection(_ section: Section) async {
        do {
            try await sectionRepository.updateSection(section)
            await loadSections()
        } catch {
            self.error = "Failed to update section: \(error.localizedDescription)"
            print("Error updating section: \(error)")
        }
    }

    @MainActor
    func deleteSection(_ sectionId: UUID) async {
        do {
            try await sectionRepository.deleteSection(id: sectionId)
            await loadSections()
        } catch {
            self.error = "Failed to delete section: \(error.localizedDescription)"
            print("Error deleting section: \(error)")
        }
    }
}

#Preview {
    SectionsView(course: Course(
        id: UUID(),
        name: "PSYCH 10",
        term: "Fall 2025",
        quarterStartDate: Date(),
        examDay: .friday,
        totalExams: 5,
        isActive: true,
        createdBy: UUID(),
        settings: CourseSettings(),
        metadata: [:]
    ))
}
