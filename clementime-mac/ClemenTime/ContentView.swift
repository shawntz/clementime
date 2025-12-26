//
//  ContentView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCourse: Course?
    @State private var selectedSection: Section?
    @State private var hasLoadedInitialCourse = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedCourse: $selectedCourse,
                selectedSection: $selectedSection,
                hasLoadedInitialCourse: $hasLoadedInitialCourse
            )
        } detail: {
            if let section = selectedSection, let course = selectedCourse {
                SectionDashboardView(course: course, section: section)
                    .id(section.id) // Force view recreation when section changes
            } else if let course = selectedCourse {
                CourseDetailView(course: course)
                    .id(course.id) // Force view recreation when course changes
            } else {
                WelcomeView()
            }
        }
        .sheet(isPresented: $appState.showCourseCreator) {
            CourseOnboardingFlow()
        }
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 120))
                .foregroundColor(.accentColor)

            Text("🍊 Welcome to Clementime")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Manage oral exam scheduling with ease")
                .font(.title2)
                .foregroundColor(.secondary)

            Button(action: {
                appState.showCourseCreator = true
            }) {
                Label("Create Your First Course", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedCourse: Course?
    @Binding var selectedSection: Section?
    @Binding var hasLoadedInitialCourse: Bool
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = CoursesViewModel()
    @State private var searchQuery = ""
    @State private var showSearchResults = false
    @State private var expandedCourses: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            // Global Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)

                TextField("Search students...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.body)

                if !searchQuery.isEmpty {
                    Button(action: {
                        searchQuery = ""
                        showSearchResults = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onChange(of: searchQuery) { oldValue, newValue in
                if !newValue.isEmpty {
                    showSearchResults = true
                    Task {
                        await viewModel.searchStudents(query: newValue)
                    }
                } else {
                    showSearchResults = false
                }
            }

            Divider()
          Spacer()

            if showSearchResults && !searchQuery.isEmpty {
                searchResultsView
            } else {
                courseListView
            }
        }
        .navigationTitle("Clementime")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    appState.showCourseCreator = true
                }) {
                    Label("New Course", systemImage: "plus")
                }
                .help("Create a new course")
            }

            ToolbarItem(placement: .status) {
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help("Refresh course list")
            }

            ToolbarItem(placement: .status) {
                SyncStatusView()
            }
        }
        .task {
            await viewModel.loadCourses()
        }
        .onChange(of: viewModel.courses) { oldValue, newValue in
            // Auto-select first course on initial load
            if !hasLoadedInitialCourse && !newValue.isEmpty {
                selectedCourse = newValue.first
                hasLoadedInitialCourse = true
            }
        }
        .onChange(of: appState.showCourseCreator) { oldValue, newValue in
            if oldValue == true && newValue == false {
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }

    private var courseListView: some View {
        List {
            SwiftUI.Section("My Courses") {
                ForEach(viewModel.activeCourses) { course in
                    courseListItem(for: course)
                }
                .disclosureGroupStyle(CenteredDisclosureStyle())
            }

            if !viewModel.archivedCourses.isEmpty {
                SwiftUI.Section("Archived Courses") {
                    ForEach(viewModel.archivedCourses) { course in
                        archivedCourseListItem(for: course)
                    }
                    .disclosureGroupStyle(CenteredDisclosureStyle())
                }
            }

            SwiftUI.Section("Shared with Me") {
                ForEach(viewModel.sharedCourses) { course in
                    NavigationLink(value: course) {
                        CourseRow(course: course, isShared: true)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func courseListItem(for course: Course) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCourses.contains(course.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedCourses.insert(course.id)
                        Task {
                            await viewModel.loadSections(for: course.id)
                        }
                    } else {
                        expandedCourses.remove(course.id)
                    }
                }
            )
        ) {
            courseSections(for: course)
        } label: {
            courseLabel(for: course)
        }
        .contextMenu {
            courseContextMenu(for: course)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            courseSwipeActions(for: course)
        }
        .onDrag {
            viewModel.draggedCourse = course
            return NSItemProvider(object: course.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: CourseDropDelegate(
            destinationCourse: course,
            viewModel: viewModel,
            selectedCourse: $selectedCourse
        ))
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
    }

    @ViewBuilder
    private func courseSections(for course: Course) -> some View {
        ForEach(viewModel.sectionsForCourse[course.id] ?? []) { section in
            Button(action: {
                selectedCourse = course
                selectedSection = section
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.name)
                            .font(.subheadline)

                        if !section.location.isEmpty {
                            Text(section.location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if section.hasAssignedTA {
                        Image(systemName: "person.fill.checkmark")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
                .padding(.leading, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        if (viewModel.sectionsForCourse[course.id] ?? []).isEmpty {
            Spacer()
            Text("No sections assigned...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 6)
        }
    }

    private func courseLabel(for course: Course) -> some View {
        Button(action: {
            selectedCourse = course
            selectedSection = nil // Clear section selection when clicking course
        }) {
            CourseRow(course: course, isSelected: selectedCourse?.id == course.id)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedCourse?.id == course.id ?
                              Color.accentColor.opacity(0.15) : Color.clear)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func courseContextMenu(for course: Course) -> some View {
        Button(action: {
            Task {
                await viewModel.archiveCourse(course.id)
                if selectedCourse?.id == course.id {
                    selectedCourse = nil
                }
            }
        }) {
            Label("Archive Course", systemImage: "archivebox")
        }

        Divider()

        Button(role: .destructive, action: {
            Task {
                await viewModel.deleteCourse(course.id)
                if selectedCourse?.id == course.id {
                    selectedCourse = nil
                }
            }
        }) {
            Label("Delete Course", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func courseSwipeActions(for course: Course) -> some View {
        Button(role: .destructive) {
            Task {
                await viewModel.deleteCourse(course.id)
                if selectedCourse?.id == course.id {
                    selectedCourse = nil
                }
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }

        Button {
            Task {
                await viewModel.archiveCourse(course.id)
                if selectedCourse?.id == course.id {
                    selectedCourse = nil
                }
            }
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .tint(.orange)
    }

    // MARK: - Archived Course List Item

    private func archivedCourseListItem(for course: Course) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCourses.contains(course.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedCourses.insert(course.id)
                        Task {
                            await viewModel.loadSections(for: course.id)
                        }
                    } else {
                        expandedCourses.remove(course.id)
                    }
                }
            )
        ) {
            courseSections(for: course)
        } label: {
            Button(action: {
                selectedCourse = course
            }) {
                HStack(spacing: 12) {
                    CourseRow(course: course, isSelected: selectedCourse?.id == course.id, isArchived: true)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedCourse?.id == course.id ?
                                      Color.accentColor.opacity(0.15) : Color.clear)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                        )

                    Image(systemName: "archivebox.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            archivedCourseContextMenu(for: course)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
    }

    @ViewBuilder
    private func archivedCourseContextMenu(for course: Course) -> some View {
        Button(action: {
            Task {
                await viewModel.unarchiveCourse(course.id)
            }
        }) {
            Label("Unarchive Course", systemImage: "arrow.uturn.backward")
        }

        Divider()

        Button(role: .destructive, action: {
            Task {
                await viewModel.deleteCourse(course.id)
                if selectedCourse?.id == course.id {
                    selectedCourse = nil
                }
            }
        }) {
            Label("Delete Course", systemImage: "trash")
        }
    }

    private var searchResultsView: some View {
        List {
            if viewModel.isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if viewModel.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No students found")
                        .foregroundColor(.secondary)
                    Text("for \"\(searchQuery)\"")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                SwiftUI.Section(header: Text("\(viewModel.searchResults.count) student\(viewModel.searchResults.count == 1 ? "" : "s") found")) {
                    ForEach(viewModel.searchResults) { result in
                        Button(action: {
                            // Navigate to student's course
                            if let course = viewModel.courses.first(where: { $0.id == result.courseId }) {
                                selectedCourse = course
                                searchQuery = ""
                                showSearchResults = false
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.fullName)
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    if let courseName = viewModel.courses.first(where: { $0.id == result.courseId })?.name {
                                        Label(courseName, systemImage: "book.fill")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    if !result.email.isEmpty {
                                        Label(result.email, systemImage: "envelope")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Course Row

struct CourseRow: View {
    let course: Course
    var isShared: Bool = false
    var isSelected: Bool = false
    var isArchived: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Course Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(isArchived ? 0.08 : 0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: course.metadata["icon"] ?? "book.fill")
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : (isArchived ? .secondary : .accentColor))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)
                    .foregroundColor(isArchived ? .secondary : .primary)

                Text(course.term)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isShared {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Drop Delegate

struct CourseDropDelegate: DropDelegate {
    let destinationCourse: Course
    let viewModel: CoursesViewModel
    @Binding var selectedCourse: Course?

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedCourse = viewModel.draggedCourse else { return false }

        if draggedCourse.id != destinationCourse.id {
            Task {
                await viewModel.moveCourse(from: draggedCourse, to: destinationCourse)
            }
        }

        viewModel.draggedCourse = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedCourse = viewModel.draggedCourse else { return }

        if draggedCourse.id != destinationCourse.id {
            Task {
                await viewModel.moveCourse(from: draggedCourse, to: destinationCourse)
            }
        }
    }
}

// MARK: - Courses ViewModel

class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var sharedCourses: [Course] = []
    @Published var sectionsForCourse: [UUID: [Section]] = [:]
    @Published var searchResults: [Student] = []
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var error: String?
    @Published var draggedCourse: Course?

    private let courseRepository: CourseRepository
    private let sectionRepository: SectionRepository
    private let studentRepository: StudentRepository

    // Computed properties to separate active and archived courses
    var activeCourses: [Course] {
        courses.filter { $0.isActive }
    }

    var archivedCourses: [Course] {
        courses.filter { !$0.isActive }
    }

    init(
        courseRepository: CourseRepository = PersistenceController.shared.courseRepository,
        sectionRepository: SectionRepository = PersistenceController.shared.sectionRepository,
        studentRepository: StudentRepository = PersistenceController.shared.studentRepository
    ) {
        self.courseRepository = courseRepository
        self.sectionRepository = sectionRepository
        self.studentRepository = studentRepository
    }

    @MainActor
    func loadCourses() async {
        isLoading = true
        error = nil

        do {
            let fetchedCourses = try await courseRepository.fetchCourses()
            courses = fetchedCourses

            // Load shared courses from CloudKit shared database
            // When CloudKit is enabled, this will query CKShare records
            // and fetch courses where the current user is a participant
            sharedCourses = await loadSharedCourses()
        } catch {
            self.error = "Failed to load courses: \(error.localizedDescription)"
            print("Error loading courses: \(error)")
        }

        isLoading = false
    }

    @MainActor
    private func loadSharedCourses() async -> [Course] {
        // Placeholder for CloudKit shared courses
        // In a full implementation, this would:
        // 1. Query CKShare records where current user is a participant
        // 2. Fetch the associated course records from shared database
        // 3. Convert to Course domain models
        // For now, return empty array until CloudKit integration is complete
        return []
    }

    @MainActor
    func loadSections(for courseId: UUID) async {
        // Always reload sections to ensure sidebar stays fresh
        do {
            let sections = try await sectionRepository.fetchSections(courseId: courseId)
            sectionsForCourse[courseId] = sections
        } catch {
            print("Error loading sections for course \(courseId): \(error)")
            sectionsForCourse[courseId] = []
        }
    }

    @MainActor
    func searchStudents(query: String) async {
        isSearching = true
        searchResults = []

        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            isSearching = false
            return
        }

        do {
            // Search across all courses
            var allStudents: [Student] = []
            for course in courses {
                let students = try await studentRepository.fetchStudents(courseId: course.id)
                allStudents.append(contentsOf: students)
            }

            // Filter by name (case-insensitive)
            searchResults = allStudents.filter { student in
                student.fullName.localizedCaseInsensitiveContains(trimmedQuery) ||
                student.email.localizedCaseInsensitiveContains(trimmedQuery)
            }
        } catch {
            print("Error searching students: \(error)")
            searchResults = []
        }

        isSearching = false
    }

    @MainActor
    func refresh() async {
        // Clear cached sections to force reload
        sectionsForCourse.removeAll()
        await loadCourses()
    }

    @MainActor
    func archiveCourse(_ id: UUID) async {
        do {
            if let course = courses.first(where: { $0.id == id }) {
                var updatedCourse = course
                updatedCourse.isActive = false
                try await courseRepository.updateCourse(updatedCourse)
                await loadCourses()
            }
        } catch {
            print("Error archiving course: \(error)")
        }
    }

    @MainActor
    func deleteCourse(_ id: UUID) async {
        do {
            try await courseRepository.deleteCourse(id: id)
            await loadCourses()
        } catch {
            print("Error deleting course: \(error)")
        }
    }

    @MainActor
    func unarchiveCourse(_ id: UUID) async {
        do {
            if let course = courses.first(where: { $0.id == id }) {
                var updatedCourse = course
                updatedCourse.isActive = true
                try await courseRepository.updateCourse(updatedCourse)
                await loadCourses()
            }
        } catch {
            print("Error unarchiving course: \(error)")
        }
    }

    @MainActor
    func moveCourse(from source: Course, to destination: Course) async {
        guard let sourceIndex = courses.firstIndex(where: { $0.id == source.id }),
              let destinationIndex = courses.firstIndex(where: { $0.id == destination.id }) else {
            return
        }

        courses.move(fromOffsets: IndexSet(integer: sourceIndex), toOffset: destinationIndex > sourceIndex ? destinationIndex + 1 : destinationIndex)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
