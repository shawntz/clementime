//
//  CourseDetailView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @State private var selectedTab: Tab = .schedule

    enum Tab: String, CaseIterable, Identifiable {
        case schedule = "Schedule"
        case students = "Students"
        case sessions = "Exam Sessions"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .schedule: return "calendar"
            case .students: return "person.3"
            case .sessions: return "list.bullet"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView(course: course)
                .tabItem {
                    Label(Tab.schedule.rawValue, systemImage: Tab.schedule.icon)
                }
                .tag(Tab.schedule)

            StudentsView(course: course)
                .tabItem {
                    Label(Tab.students.rawValue, systemImage: Tab.students.icon)
                }
                .tag(Tab.students)

            ExamSessionsView(course: course)
                .tabItem {
                    Label(Tab.sessions.rawValue, systemImage: Tab.sessions.icon)
                }
                .tag(Tab.sessions)

            CourseSettingsView(course: course)
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .navigationTitle(course.name)
        .navigationSubtitle(course.term)
    }
}

// MARK: - Placeholder Views (to be implemented)

struct ScheduleView: View {
    let course: Course

    var body: some View {
        VStack {
            Text("Schedule View")
                .font(.title)
            Text("TODO: Implement schedule view with exam slot management")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StudentsView: View {
    let course: Course

    var body: some View {
        VStack {
            Text("Students View")
                .font(.title)
            Text("TODO: Implement student roster management")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ExamSessionsView: View {
    let course: Course

    var body: some View {
        VStack {
            Text("Exam Sessions View")
                .font(.title)
            Text("TODO: Implement exam session builder with cohorts")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CourseSettingsView: View {
    let course: Course

    var body: some View {
        VStack {
            Text("Course Settings View")
                .font(.title)
            Text("TODO: Implement course settings and TA invitations")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("App Settings")
                .font(.title)
            Text("TODO: Implement app preferences")
                .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 300)
    }
}

struct CourseBuilderView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Course Builder")
                .font(.title)
            Text("TODO: Implement course creation wizard")
                .foregroundColor(.secondary)

            Button("Cancel") {
                dismiss()
            }
        }
        .frame(width: 600, height: 500)
        .padding()
    }
}
