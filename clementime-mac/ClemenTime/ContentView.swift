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

    var body: some View {
        List(selection: $selectedCourse) {
            SwiftUI.Section("My Courses") {
                ForEach(viewModel.courses) { course in
                    NavigationLink(value: course) {
                        CourseRow(course: course)
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
            // Refresh courses when modal is dismissed
            if oldValue == true && newValue == false {
                Task {
                    await viewModel.refresh()
                }
            }
        }
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
    @Published var isLoading = false
    @Published var error: String?

    private let courseRepository: CourseRepository

    init(courseRepository: CourseRepository = PersistenceController.shared.courseRepository) {
        self.courseRepository = courseRepository
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

    func createNewCourse() {
        // This is handled by AppState.showCourseCreator
    }

    @MainActor
    func refresh() async {
        await loadCourses()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
