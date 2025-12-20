//
//  CourseDetailView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
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
