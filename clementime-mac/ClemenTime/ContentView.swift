//
//  ContentView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCourse: Course?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedCourse: $selectedCourse)
        } detail: {
            if let course = selectedCourse {
                CourseDetailView(course: course)
            } else {
                WelcomeView()
            }
        }
        .sheet(isPresented: $appState.showCourseCreator) {
            CourseBuilderView()
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
            }

            ToolbarItem {
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task {
            await viewModel.loadCourses()
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
                ForEach(viewModel.courses) { course in
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
                        // Nested sections
                        ForEach(viewModel.sectionsForCourse[course.id] ?? []) { section in
                            Button(action: {
                                selectedCourse = course
                                // TODO: Navigate to section-specific schedule view
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
                            Text("No sections")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 28)
                        }
                    } label: {
                        Button(action: {
                            selectedCourse = course
                        }) {
                            CourseRow(course: course)
                        }
                        .buttonStyle(.plain)
                    }
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

    var body: some View {
        HStack(spacing: 12) {
            // Course Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: course.metadata["icon"] ?? "book.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.name)
                    .font(.headline)

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

    private let courseRepository: CourseRepository
    private let sectionRepository: SectionRepository
    private let studentRepository: StudentRepository

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
            sharedCourses = [] // TODO: Implement shared courses when CloudKit is enabled
        } catch {
            self.error = "Failed to load courses: \(error.localizedDescription)"
            print("Error loading courses: \(error)")
        }

        isLoading = false
    }

    @MainActor
    func loadSections(for courseId: UUID) async {
        // Skip if already loaded
        if sectionsForCourse[courseId] != nil {
            return
        }

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
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
