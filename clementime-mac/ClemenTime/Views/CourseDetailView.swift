//
//  CourseDetailView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @State private var selectedTab: CourseTab = .sections

    enum CourseTab: String, CaseIterable, Identifiable {
        case sections = "Sections"
        case students = "Students"
        case sessions = "Exam Sessions"
        case schedule = "Schedule"
        case settings = "Settings"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .sections: return "square.grid.2x2"
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
            HStack(spacing: 16) {
                // Course Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: course.metadata["icon"] ?? "book.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(course.name)
                        .font(.title)
                        .fontWeight(.bold)

                    if let description = course.metadata["description"], !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        Label(course.term, systemImage: "calendar")
                        Label("\(course.totalExams) Exams", systemImage: "doc.text")
                    }
                    .font(.caption)
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
                SectionsView(course: course)
                    .tag(CourseTab.sections)

                StudentsView(course: course)
                    .tag(CourseTab.students)

                ExamSessionsView(course: course)
                    .tag(CourseTab.sessions)

                ScheduleView(course: course)
                    .tag(CourseTab.schedule)

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
            quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(),
            totalExams: 5,
            isActive: true,
            createdBy: UUID(),
            settings: CourseSettings()
        ))
    }
}
