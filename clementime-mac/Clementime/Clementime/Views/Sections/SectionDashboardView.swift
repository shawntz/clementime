//
//  SectionDashboardView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/21/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct SectionDashboardView: View {
    let course: Course
    let section: Section

    @State private var students: [Student] = []
    @State private var examSlots: [ExamSlot] = []
    @State private var examSessions: [ExamSession] = []
    @State private var isLoading = false
    @State private var showEditSection = false
    @State private var showDeleteConfirmation = false
    @State private var showAddStudent = false
    @State private var recordings: [Recording] = []
    @Environment(\.dismiss) private var dismiss

    private let sectionRepository = PersistenceController.shared.sectionRepository
    private let studentRepository = PersistenceController.shared.studentRepository
    private let scheduleRepository = PersistenceController.shared.scheduleRepository
    private let recordingRepository = PersistenceController.shared.recordingRepository
    private let cohortRepository = PersistenceController.shared.cohortRepository
    private let examSessionRepository = PersistenceController.shared.examSessionRepository
    private let constraintRepository = PersistenceController.shared.constraintRepository

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                sectionHeader

                Divider()

                // Stats Grid
                statsGrid

                Divider()

                // Students List
                studentsSection

                Divider()

                // Exam Slots Section
                examSlotsSection
            }
            .padding()
        }
        .navigationTitle(section.name)
        .navigationSubtitle("\(students.count) student\(students.count == 1 ? "" : "s")")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showEditSection = true
                    } label: {
                        Label("Edit Section", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Section", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .help("Section options")
            }
        }
        .task {
            await loadData()
        }
        .sheet(isPresented: $showEditSection) {
            SectionEditorView(courseId: course.id, section: section) { updatedSection in
                Task {
                    await updateSection(updatedSection)
                }
            }
        }
        .alert("Delete Section?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteSection()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(section.name)? This cannot be undone.")
        }
        .sheet(isPresented: $showAddStudent) {
            StudentEditorView(courseId: course.id, sectionId: section.id) { newStudent in
                Task {
                    await addStudent(newStudent)
                }
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(section.code)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                Label(section.weekdayName, systemImage: "calendar")
                Label(section.formattedTimeRange, systemImage: "clock")
                Label(section.location, systemImage: "mappin.circle")
            }
            .font(.callout)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "Students",
                value: "\(students.count)",
                icon: "person.3.fill",
                color: .blue
            )

            StatCard(
                title: "Scheduled",
                value: "\(scheduledSlotsCount)",
                icon: "checkmark.circle.fill",
                color: .green
            )

            StatCard(
                title: "Unscheduled",
                value: "\(unscheduledSlotsCount)",
                icon: "exclamationmark.circle.fill",
                color: .orange
            )

            StatCard(
                title: "Recordings",
                value: "\(recordingsCount)",
                icon: "waveform.circle.fill",
                color: .purple
            )
        }
    }

    private var scheduledSlotsCount: Int {
        examSlots.filter { $0.isScheduled }.count
    }

    private var unscheduledSlotsCount: Int {
        examSlots.filter { !$0.isScheduled }.count
    }

    private var recordingsCount: Int {
        recordings.count
    }

    // MARK: - Students Section

    private var studentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Students")
                    .font(.headline)

                Spacer()

                Button {
                    showAddStudent = true
                } label: {
                    Label("Add Student", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if students.isEmpty {
                emptyStudentsView
            } else {
                ForEach(students) { student in
                    StudentRow(student: student)
                }
            }
        }
    }

    private var emptyStudentsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Students")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Import a roster or add students manually")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Exam Slots Section

    private var examSlotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exam Schedule")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await generateSchedule()
                    }
                } label: {
                    Label("Generate Schedule", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if examSlots.isEmpty {
                emptyExamSlotsView
            } else {
                ExamSlotScheduler(
                    examSlots: $examSlots,
                    students: students,
                    examSessions: examSessions,
                    onSlotUpdated: { updatedSlot in
                        Task {
                            await updateExamSlot(updatedSlot)
                        }
                    }
                )
            }
        }
    }

    private var emptyExamSlotsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Exam Slots")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Generate a schedule to create exam slots for students")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        do {
            students = try await studentRepository.fetchStudents(courseId: course.id)
                .filter { $0.sectionId == section.id }
            let allSlots = try await scheduleRepository.fetchExamSlots(courseId: course.id)
            examSlots = allSlots.filter { $0.sectionId == section.id }
            examSessions = try await examSessionRepository.fetchExamSessions(courseId: course.id)
            recordings = try await recordingRepository.fetchRecordings(courseId: course.id)
                .filter { recording in
                    examSlots.contains { $0.id == recording.examSlotId }
                }
        } catch {
            print("Failed to load section data: \(error)")
        }
        isLoading = false
    }

    private func updateSection(_ updatedSection: Section) async {
        do {
            try await sectionRepository.updateSection(updatedSection)
            // Reload data if needed
        } catch {
            print("Failed to update section: \(error)")
        }
    }

    private func deleteSection() async {
        do {
            try await sectionRepository.deleteSection(id: section.id)
            dismiss()
        } catch {
            print("Failed to delete section: \(error)")
        }
    }

    private func generateSchedule() async {
        do {
            let generateScheduleUseCase = GenerateScheduleUseCase(
                courseRepository: PersistenceController.shared.courseRepository,
                cohortRepository: cohortRepository,
                studentRepository: studentRepository,
                sectionRepository: sectionRepository,
                examSessionRepository: examSessionRepository,
                constraintRepository: constraintRepository,
                scheduleRepository: scheduleRepository
            )
            let input = GenerateScheduleInput(courseId: course.id, startingFromExam: nil)
            _ = try await generateScheduleUseCase.execute(input: input)
            await loadData()
        } catch {
            print("Failed to generate schedule: \(error)")
        }
    }

    private func addStudent(_ student: Student) async {
        do {
            _ = try await studentRepository.createStudent(student)
            await loadData()
        } catch {
            print("Failed to add student: \(error)")
        }
    }

    private func updateExamSlot(_ slot: ExamSlot) async {
        do {
            try await scheduleRepository.updateExamSlot(slot)
            await loadData()
        } catch {
            print("Failed to update exam slot: \(error)")
        }
    }
}

// MARK: - Student Editor

struct StudentEditorView: View {
    @Environment(\.dismiss) var dismiss
    let courseId: UUID
    let sectionId: UUID?
    let student: Student?
    let onSave: (Student) -> Void

    @State private var fullName = ""
    @State private var email = ""
    @State private var sisUserId = ""
    @State private var selectedSectionId: UUID?
    @State private var selectedCohortId: UUID?
    @State private var slackUserId = ""
    @State private var slackUsername = ""
    @State private var isActive = true

    @State private var sections: [Section] = []
    @State private var cohorts: [Cohort] = []

    private let sectionRepository = PersistenceController.shared.sectionRepository
    private let cohortRepository = PersistenceController.shared.cohortRepository

    init(courseId: UUID, sectionId: UUID? = nil, student: Student? = nil, onSave: @escaping (Student) -> Void) {
        self.courseId = courseId
        self.sectionId = sectionId
        self.student = student
        self.onSave = onSave

        // Initialize with existing student data or defaults
        if let student = student {
            _fullName = State(initialValue: student.fullName)
            _email = State(initialValue: student.email)
            _sisUserId = State(initialValue: student.sisUserId)
            _selectedSectionId = State(initialValue: student.sectionId)
            _selectedCohortId = State(initialValue: student.cohortId)
            _slackUserId = State(initialValue: student.slackUserId ?? "")
            _slackUsername = State(initialValue: student.slackUsername ?? "")
            _isActive = State(initialValue: student.isActive)
        } else if let sectionId = sectionId {
            _selectedSectionId = State(initialValue: sectionId)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(.plain)

                    TextField("Email", text: $email)
                        .textFieldStyle(.plain)
                        .textContentType(.emailAddress)

                    TextField("SIS User ID", text: $sisUserId)
                        .textFieldStyle(.plain)
                } header: {
                    Text("Student Information")
                        .font(.headline)
                }

                SwiftUI.Section {
                    Picker("Section", selection: $selectedSectionId) {
                        Text("Select Section").tag(nil as UUID?)

                        // Show unmatched section code if present
                        if let student = student, student.hasUnmatchedSection, let unmatchedCode = student.unmatchedSectionCode {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(unmatchedCode)
                                    .foregroundColor(.red)
                                Text("(not found)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .tag(student.sectionId as UUID?)
                        }

                        ForEach(sections) { section in
                            HStack {
                                Text(section.displayName)
                                if section.shouldIgnoreForMatching {
                                    Text("(ignored)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tag(section.id as UUID?)
                        }
                    }

                    Picker("Cohort", selection: $selectedCohortId) {
                        Text("Select Cohort").tag(nil as UUID?)
                        ForEach(cohorts) { cohort in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: cohort.colorHex) ?? .blue)
                                    .frame(width: 10, height: 10)
                                Text(cohort.name)
                            }
                            .tag(cohort.id as UUID?)
                        }
                    }
                } header: {
                    Text("Assignment")
                        .font(.headline)
                }

                SwiftUI.Section {
                    TextField("Slack User ID (optional)", text: $slackUserId)
                        .textFieldStyle(.plain)

                    TextField("Slack Username (optional)", text: $slackUsername)
                        .textFieldStyle(.plain)
                } header: {
                    Text("Slack Integration")
                        .font(.headline)
                }

                SwiftUI.Section {
                    Toggle(isOn: $isActive) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Active Student")
                                .fontWeight(.medium)
                            Text("Inactive students won't be scheduled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Status")
                        .font(.headline)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(student == nil ? "Add Student" : "Edit Student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(student == nil ? "Create" : "Save") {
                        saveStudent()
                    }
                    .disabled(!isValid)
                    .buttonStyle(.borderedProminent)
                }
            }
            .task {
                await loadData()
            }
        }
        .frame(minWidth: 500, idealWidth: 600, minHeight: 500, idealHeight: 600)
    }

    private var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !sisUserId.trimmingCharacters(in: .whitespaces).isEmpty &&
        selectedSectionId != nil &&
        selectedCohortId != nil
    }

    private func loadData() async {
        do {
            sections = try await sectionRepository.fetchSections(courseId: courseId)
            cohorts = try await cohortRepository.fetchCohorts(courseId: courseId)

            // If creating new student and there's a default cohort, select it
            if student == nil, let defaultCohort = cohorts.first(where: { $0.isDefault }) {
                selectedCohortId = defaultCohort.id
            }
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    private func saveStudent() {
        guard let sectionId = selectedSectionId,
              let cohortId = selectedCohortId else {
            return
        }

        let newStudent = Student(
            id: student?.id ?? UUID(),
            courseId: courseId,
            sectionId: sectionId,
            sisUserId: sisUserId.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            cohortId: cohortId,
            slackUserId: slackUserId.isEmpty ? nil : slackUserId.trimmingCharacters(in: .whitespaces),
            slackUsername: slackUsername.isEmpty ? nil : slackUsername.trimmingCharacters(in: .whitespaces),
            isActive: isActive,
            unmatchedSectionCode: nil
        )

        onSave(newStudent)
        dismiss()
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 14, alignment: .top)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StudentRow: View {
    let student: Student
    @State private var studentSlots: [ExamSlot] = []
    @State private var studentRecordings: [Recording] = []
    @State private var examSessions: [ExamSession] = []
    @State private var showStudentDetail = false
    @State private var isLoading = false

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(student.fullName)
                    .font(.body)

                Text(student.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Student Stats
            if isLoading {
                ProgressView()
                    .scaleEffect(0.6)
            } else {
                HStack(spacing: 12) {
                    // Scheduled exams stat
                    StatPill(
                        icon: "calendar.badge.checkmark",
                        value: "\(scheduledCount)",
                        label: "Scheduled",
                        color: .green
                    )

                    // Completed exams stat
                    StatPill(
                        icon: "checkmark.circle.fill",
                        value: "\(completedCount)",
                        label: "Completed",
                        color: .blue
                    )

                    // Recordings stat
                    StatPill(
                        icon: "waveform.circle",
                        value: "\(recordingsCount)",
                        label: "Recorded",
                        color: .purple
                    )

                    // Actions menu
                    Menu {
                        Button {
                            showStudentDetail = true
                        } label: {
                            Label("View Details", systemImage: "person.text.rectangle")
                        }

                        Button {
                            // View exam history
                        } label: {
                            Label("Exam History", systemImage: "clock")
                        }

                        Divider()

                        Button {
                            // Email student
                            if let url = URL(string: "mailto:\(student.email)") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("Email Student", systemImage: "envelope")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadStudentData()
        }
        .sheet(isPresented: $showStudentDetail) {
            StudentDetailView(student: student, slots: studentSlots, recordings: studentRecordings, examSessions: examSessions)
        }
    }

    private var scheduledCount: Int {
        studentSlots.filter { $0.isScheduled }.count
    }

    private var completedCount: Int {
        studentRecordings.count
    }

    private var recordingsCount: Int {
        studentRecordings.count
    }

    private func loadStudentData() async {
        isLoading = true
        do {
            let scheduleRepo = PersistenceController.shared.scheduleRepository
            let recordingRepo = PersistenceController.shared.recordingRepository
            let examSessionRepo = PersistenceController.shared.examSessionRepository

            // Fetch all slots for this student
            let allSlots = try await scheduleRepo.fetchExamSlots(courseId: student.courseId)
            studentSlots = allSlots.filter { $0.studentId == student.id }

            // Fetch all recordings for this student
            studentRecordings = try await recordingRepo.fetchRecordings(studentId: student.id)

            // Fetch exam sessions
            examSessions = try await examSessionRepo.fetchExamSessions(courseId: student.courseId)
        } catch {
            print("Failed to load student data: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Student Detail View

struct StudentDetailView: View {
    @Environment(\.dismiss) var dismiss
    let student: Student
    let slots: [ExamSlot]
    let recordings: [Recording]
    let examSessions: [ExamSession]

    var body: some View {
        NavigationStack {
            Form {
                SwiftUI.Section("Student Information") {
                    LabeledContent("Name", value: student.fullName)
                    LabeledContent("Email", value: student.email)
                    LabeledContent("SIS User ID", value: student.sisUserId)
                }

                SwiftUI.Section("Exam Statistics") {
                    LabeledContent("Total Exam Slots", value: "\(slots.count)")
                    LabeledContent("Scheduled", value: "\(slots.filter { $0.isScheduled }.count)")
                    LabeledContent("Recordings", value: "\(recordings.count)")
                }

                if !slots.isEmpty {
                    SwiftUI.Section("Exam Slots") {
                        ForEach(slots) { slot in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    let examNum = examSessions.first(where: { $0.id == slot.examSessionId })?.examNumber ?? 0
                                    Text("Exam \(examNum)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    if slot.isScheduled {
                                        Text(slot.formattedTimeRange)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Not scheduled")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }

                                Spacer()

                                if slot.isScheduled {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(student.fullName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Exam Slot Scheduler

struct ExamSlotScheduler: View {
    @Binding var examSlots: [ExamSlot]
    let students: [Student]
    let examSessions: [ExamSession]
    let onSlotUpdated: (ExamSlot) -> Void

    @State private var draggedSlot: ExamSlot?
    @State private var selectedExamNumber: Int = 1
    @State private var groupedSlots: [Int: [ExamSlot]] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Exam selector
            HStack {
                Text("Select Exam:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Exam", selection: $selectedExamNumber) {
                    ForEach(availableExams, id: \.self) { examNum in
                        Text("Exam \(examNum)").tag(examNum)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()
            }

            // Scheduler grid
            if let slotsForExam = groupedSlots[selectedExamNumber], !slotsForExam.isEmpty {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(slotsForExam) { slot in
                            ExamSlotCard(
                                slot: slot,
                                student: students.first(where: { $0.id == slot.studentId }),
                                isDragging: draggedSlot?.id == slot.id,
                                onSlotUpdated: onSlotUpdated
                            )
                            .onDrag {
                                draggedSlot = slot
                                return NSItemProvider(object: slot.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: SlotDropDelegate(
                                slot: slot,
                                draggedSlot: $draggedSlot,
                                examSlots: $examSlots,
                                onSlotUpdated: onSlotUpdated
                            ))
                        }
                    }
                }
            } else {
                Text("No exam slots for Exam \(selectedExamNumber)")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            }
        }
        .onAppear {
            groupSlotsByExam()
            if let firstExam = availableExams.first {
                selectedExamNumber = firstExam
            }
        }
        .onChange(of: examSlots) {
            groupSlotsByExam()
        }
    }

    private func examNumber(for slot: ExamSlot) -> Int {
        examSessions.first(where: { $0.id == slot.examSessionId })?.examNumber ?? 0
    }

    private var availableExams: [Int] {
        Array(Set(examSlots.compactMap { slot in
            examSessions.first(where: { $0.id == slot.examSessionId })?.examNumber
        })).sorted()
    }

    private func groupSlotsByExam() {
        groupedSlots = Dictionary(grouping: examSlots, by: { slot in
            examSessions.first(where: { $0.id == slot.examSessionId })?.examNumber ?? 0
        })
    }
}

// MARK: - Exam Slot Card

struct ExamSlotCard: View {
    let slot: ExamSlot
    let student: Student?
    let isDragging: Bool
    let onSlotUpdated: (ExamSlot) -> Void

    @State private var showEditSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let student = student {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.fullName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(student.email)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("No Student")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Menu {
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    if slot.isLocked {
                        Button {
                            var updatedSlot = slot
                            updatedSlot.isLocked = false
                            onSlotUpdated(updatedSlot)
                        } label: {
                            Label("Unlock", systemImage: "lock.open")
                        }
                    } else {
                        Button {
                            var updatedSlot = slot
                            updatedSlot.isLocked = true
                            onSlotUpdated(updatedSlot)
                        } label: {
                            Label("Lock", systemImage: "lock")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
            }

            Divider()

            // Time info
            if slot.isScheduled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(slot.formattedDate)
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(slot.formattedTimeRange)
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            } else {
                Text("Not Scheduled")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Status indicators
            HStack(spacing: 8) {
                if slot.isLocked {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                if slot.isScheduled {
                    Label("Scheduled", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }

                Spacer()

                Image(systemName: "hand.raised.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(isDragging ? 0.5 : 0.0)
            }
        }
        .padding()
        .background(isDragging ? Color.accentColor.opacity(0.2) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(slot.isLocked ? Color.blue : Color.gray.opacity(0.2), lineWidth: slot.isLocked ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .opacity(isDragging ? 0.5 : 1.0)
    }
}

// MARK: - Slot Drop Delegate

struct SlotDropDelegate: DropDelegate {
    let slot: ExamSlot
    @Binding var draggedSlot: ExamSlot?
    @Binding var examSlots: [ExamSlot]
    let onSlotUpdated: (ExamSlot) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedSlot = draggedSlot else { return false }
        guard draggedSlot.id != slot.id else { return false }

        // Swap the time slots between the two exam slots
        if let draggedIndex = examSlots.firstIndex(where: { $0.id == draggedSlot.id }),
           let targetIndex = examSlots.firstIndex(where: { $0.id == slot.id }) {

            var updatedDraggedSlot = draggedSlot
            var updatedTargetSlot = slot

            // Swap scheduled times
            let tempDate = updatedDraggedSlot.date
            let tempStartTime = updatedDraggedSlot.startTime
            let tempEndTime = updatedDraggedSlot.endTime
            let tempIsScheduled = updatedDraggedSlot.isScheduled

            updatedDraggedSlot.date = updatedTargetSlot.date
            updatedDraggedSlot.startTime = updatedTargetSlot.startTime
            updatedDraggedSlot.endTime = updatedTargetSlot.endTime
            updatedDraggedSlot.isScheduled = updatedTargetSlot.isScheduled

            updatedTargetSlot.date = tempDate
            updatedTargetSlot.startTime = tempStartTime
            updatedTargetSlot.endTime = tempEndTime
            updatedTargetSlot.isScheduled = tempIsScheduled

            // Update the array
            examSlots[draggedIndex] = updatedDraggedSlot
            examSlots[targetIndex] = updatedTargetSlot

            // Notify of updates
            onSlotUpdated(updatedDraggedSlot)
            onSlotUpdated(updatedTargetSlot)
        }

        self.draggedSlot = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // Visual feedback when hovering
    }

    func dropExited(info: DropInfo) {
        // Visual feedback when leaving
    }
}

#Preview {
    NavigationStack {
        SectionDashboardView(
            course: Course(
                id: UUID(),
                name: "PSYCH 10",
                term: "Fall 2025",
                quarterStartDate: Date(),
                quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(),
                totalExams: 5,
                isActive: true,
                createdBy: UUID(),
                settings: CourseSettings()
            ),
            section: Section(
                id: UUID(),
                courseId: UUID(),
                code: "F25-PSYCH-10-02",
                name: "Section 02",
                location: "Building 420, Room 245",
                assignedTAId: nil,
                weekday: 6,
                startTime: "13:30",
                endTime: "14:50",
                isActive: true
            )
        )
    }
}
