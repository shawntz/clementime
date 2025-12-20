//
//  ContentView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
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
                .font(.system(size: 172))
                .foregroundColor(.accentColor)

            Text("Welcome to ClemenTime")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Manage oral exam schedules with ease")
                .font(.title3)
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
        .navigationTitle("ClemenTime")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.createNewCourse()
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

// MARK: - Placeholder ViewModels (will be implemented later)

class CoursesViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var sharedCourses: [Course] = []
    @Published var isLoading = false

    func loadCourses() async {
        // TODO: Implement course loading from Core Data/CloudKit
        isLoading = true
        // Placeholder: await courseRepository.fetchCourses()
        isLoading = false
    }

    func createNewCourse() {
        // TODO: Show course creator
    }

    func refresh() async {
        await loadCourses()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
