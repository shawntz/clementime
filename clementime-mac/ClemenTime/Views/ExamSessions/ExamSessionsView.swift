//
//  ExamSessionsView.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

struct ExamSessionsView: View {
    let course: Course
    @State private var examSessions: [ExamSession] = []
    @State private var isLoading = false
    @State private var showAddSession = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()

            // Main content
            if isLoading {
                ProgressView("Loading exam sessions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if examSessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .task {
            await loadSessions()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Text("Exam Sessions")
                .font(.headline)

            Spacer()

            Button(action: {
                showAddSession = true
            }) {
                Label("Add Session", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(examSessions) { session in
                    ExamSessionCard(session: session, course: course)
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.bullet")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("No Exam Sessions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add exam sessions to configure dates and times for oral exams")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                showAddSession = true
            }) {
                Label("Add Exam Session", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Data Loading

    private func loadSessions() async {
        isLoading = true
        // TODO: Load sessions from repository
        // For now, use placeholder data
        isLoading = false
    }
}

// MARK: - Exam Session Card

struct ExamSessionCard: View {
    let session: ExamSession
    let course: Course

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Exam \(session.examNumber)")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let theme = session.theme {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(theme)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button(action: {}) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: {}, role: .destructive) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            Divider()

            // Dates for each cohort
            VStack(alignment: .leading, spacing: 8) {
                DateRow(
                    label: "Odd Week",
                    date: session.oddWeekDate,
                    color: .blue
                )

                DateRow(
                    label: "Even Week",
                    date: session.evenWeekDate,
                    color: .green
                )
            }

            Divider()

            // Time details
            HStack(spacing: 24) {
                InfoItem(
                    icon: "clock",
                    label: "Time",
                    value: "\(session.startTime) - \(session.endTime)"
                )

                InfoItem(
                    icon: "timer",
                    label: "Duration",
                    value: "\(session.durationMinutes) min"
                )

                InfoItem(
                    icon: "hourglass",
                    label: "Buffer",
                    value: "\(session.bufferMinutes) min"
                )
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
}

struct DateRow: View {
    let label: String
    let date: Date
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(date, style: .date)
                .font(.body)
                .fontWeight(.medium)

            Spacer()
        }
    }
}

struct InfoItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

#Preview {
    ExamSessionsView(course: Course(
        id: UUID(),
        name: "PSYCH 10",
        term: "Fall 2025",
        quarterStartDate: Date(),
        examDay: .friday,
        totalExams: 5,
        isActive: true,
        createdBy: UUID(),
        settings: CourseSettings()
    ))
}
