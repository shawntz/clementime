//
//  ExamSessionsView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

struct ExamSessionsView: View {
    let course: Course
    @State private var examSessions: [ExamSession] = []
    @State private var isLoading = false
    @State private var showAddSession = false
    @State private var cohorts: [Cohort] = []
    @State private var editingSession: ExamSession?

    private let examSessionRepository = PersistenceController.shared.examSessionRepository
    private let cohortRepository = PersistenceController.shared.cohortRepository

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
        .sheet(isPresented: $showAddSession) {
            ExamSessionEditorView(course: course) { newSession in
                Task {
                    await saveExamSession(newSession)
                }
            }
        }
        .sheet(item: $editingSession) { session in
            ExamSessionEditorView(course: course, existingSession: session) { updatedSession in
                Task {
                    await updateExamSession(updatedSession)
                }
            }
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
        List {
            ForEach(examSessions) { session in
                ExamSessionCard(
                    session: session,
                    course: course,
                    cohortName: cohortName(for: session.assignedCohortId),
                    onEdit: {
                        editingSession = session
                    },
                    onDelete: {
                        Task {
                            await deleteExamSession(session)
                        }
                    }
                )
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                await deleteExamSession(session)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            editingSession = session
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.plain)
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
        do {
            examSessions = try await examSessionRepository.fetchExamSessions(courseId: course.id)
            cohorts = try await cohortRepository.fetchCohorts(courseId: course.id)
        } catch {
            print("Failed to load exam sessions: \(error)")
        }
        isLoading = false
    }

    private func cohortName(for cohortId: UUID?) -> String {
        guard let cohortId = cohortId else { return "All Students" }
        return cohorts.first(where: { $0.id == cohortId })?.name ?? "Unknown Cohort"
    }

    private func saveExamSession(_ session: ExamSession) async {
        do {
            _ = try await examSessionRepository.createExamSession(session)
            await loadSessions()
        } catch {
            print("Failed to save exam session: \(error)")
        }
    }

    private func updateExamSession(_ session: ExamSession) async {
        do {
            try await examSessionRepository.updateExamSession(session)
            await loadSessions()
        } catch {
            print("Failed to update exam session: \(error)")
        }
    }

    private func deleteExamSession(_ session: ExamSession) async {
        do {
            try await examSessionRepository.deleteExamSession(id: session.id)
            await loadSessions()
        } catch {
            print("Failed to delete exam session: \(error)")
        }
    }
}

// MARK: - Exam Session Card

struct ExamSessionCard: View {
    let session: ExamSession
    let course: Course
    let cohortName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

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
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            Divider()

            // Week start date
            VStack(alignment: .leading, spacing: 8) {
                DateRow(
                    label: "Week Starting",
                    date: session.weekStartDate,
                    color: .blue
                )

                Text(cohortName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Exam duration details
            HStack(spacing: 24) {
                InfoItem(
                    icon: "clock",
                    label: "Duration",
                    value: "\(session.durationMinutes) min"
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
        quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(),
        totalExams: 5,
        isActive: true,
        createdBy: UUID(),
        settings: CourseSettings()
    ))
}
