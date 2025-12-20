//
//  CourseDetailView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @State private var selectedTab: CourseTab = .structure

    enum CourseTab: String, CaseIterable, Identifiable {
        case structure = "Structure"
        case schedule = "Schedule"
        case students = "Students"
        case sessions = "Sessions"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .structure: return "flowchart"
            case .schedule: return "calendar"
            case .students: return "person.3"
            case .sessions: return "clock"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Course Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.title)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        Label(course.term, systemImage: "calendar")
                        Label(course.examDay.rawValue.capitalized, systemImage: "clock")
                        Label("\(course.totalExams) Exams", systemImage: "doc.text")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if !course.isActive {
                    Text("Archived")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Tab Picker
            Picker("View", selection: $selectedTab) {
                ForEach(CourseTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab Content
            TabView(selection: $selectedTab) {
                ExamStructureCanvasView(course: course)
                    .tag(CourseTab.structure)

                ScheduleView(course: course)
                    .tag(CourseTab.schedule)

                StudentsView(course: course)
                    .tag(CourseTab.students)

                ExamSessionsView(course: course)
                    .tag(CourseTab.sessions)

                CourseSettingsView(course: course)
                    .tag(CourseTab.settings)
            }
            .tabViewStyle(.automatic)
        }
        .navigationTitle(course.name)
    }
}

#Preview {
    NavigationStack {
        CourseDetailView(course: Course(
            id: UUID(),
            name: "PSYCH 10 / STATS 60",
            term: "Fall 2025",
            quarterStartDate: Date(),
            examDay: .friday,
            totalExams: 5,
            isActive: true,
            createdBy: UUID(),
            settings: CourseSettings()
        ))
    }
}
