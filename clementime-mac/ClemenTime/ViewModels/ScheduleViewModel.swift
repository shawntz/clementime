//
//  ScheduleViewModel.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import Combine
import AppKit

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var examSlots: [ExamSlot] = []
    @Published var students: [Student] = []
    @Published var sections: [Section] = []
    @Published var examSessions: [ExamSession] = []
    @Published var selectedExamNumber: Int = 1
    @Published var isGenerating = false
    @Published var isExporting = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var successMessage: String?
    @Published var canEditSchedule = false

    private let course: Course
    private let scheduleRepository: ScheduleRepository
    private let studentRepository: StudentRepository
    private let sectionRepository: SectionRepository
    private let examSessionRepository: ExamSessionRepository
    private let generateScheduleUseCase: GenerateScheduleUseCase
    private let exportScheduleUseCase: ExportScheduleUseCase
    private let permissionChecker: PermissionChecker

    init(
        course: Course,
        scheduleRepository: ScheduleRepository,
        studentRepository: StudentRepository,
        sectionRepository: SectionRepository,
        examSessionRepository: ExamSessionRepository,
        generateScheduleUseCase: GenerateScheduleUseCase,
        exportScheduleUseCase: ExportScheduleUseCase,
        permissionChecker: PermissionChecker
    ) {
        self.course = course
        self.scheduleRepository = scheduleRepository
        self.studentRepository = studentRepository
        self.sectionRepository = sectionRepository
        self.examSessionRepository = examSessionRepository
        self.generateScheduleUseCase = generateScheduleUseCase
        self.exportScheduleUseCase = exportScheduleUseCase
        self.permissionChecker = permissionChecker

        self.canEditSchedule = permissionChecker.can(.editSchedules)
    }

    func loadData() async {
        isLoading = true
        error = nil

        do {
            // Load all data in parallel
            async let slotsTask = scheduleRepository.fetchExamSlots(courseId: course.id)
            async let studentsTask = studentRepository.fetchStudents(courseId: course.id)
            async let sectionsTask = sectionRepository.fetchSections(courseId: course.id)
            async let sessionsTask = examSessionRepository.fetchExamSessions(courseId: course.id)

            examSlots = try await slotsTask
            students = try await studentsTask
            sections = try await sectionsTask
            examSessions = try await sessionsTask

            // Set default selected exam to first session
            if let firstSession = examSessions.sorted(by: { $0.examNumber < $1.examNumber }).first {
                selectedExamNumber = firstSession.examNumber
            }
        } catch {
            self.error = "Failed to load schedule data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func generateSchedule(startingFromExam: Int? = nil) async {
        guard permissionChecker.can(.editSchedules) else {
            error = "You don't have permission to edit schedules"
            return
        }

        isGenerating = true
        error = nil
        successMessage = nil

        do {
            let input = GenerateScheduleInput(
                courseId: course.id,
                startingFromExam: startingFromExam
            )

            let result = try await generateScheduleUseCase.execute(input: input)

            if !result.errors.isEmpty {
                error = "Generated with some errors:\n" + result.errors.joined(separator: "\n")
            } else {
                successMessage = "Successfully generated \(result.scheduledCount) exam slots. \(result.unscheduledCount) students could not be scheduled due to constraints."
            }

            // Reload data
            await loadData()
        } catch {
            self.error = "Failed to generate schedule: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    func exportSchedule(examNumber: Int? = nil, includeUnscheduled: Bool = true) async {
        guard permissionChecker.can(.exportData) else {
            error = "You don't have permission to export data"
            return
        }

        isExporting = true
        error = nil

        do {
            let input = ExportScheduleInput(
                courseId: course.id,
                examNumber: examNumber,
                includeUnscheduled: includeUnscheduled
            )

            let output = try await exportScheduleUseCase.execute(input: input)

            // Open the file in Finder
            NSWorkspace.shared.selectFile(output.csvURL.path, inFileViewerRootedAtPath: "")

            successMessage = "Exported \(output.rowCount) rows to CSV"
        } catch {
            self.error = "Failed to export schedule: \(error.localizedDescription)"
        }

        isExporting = false
    }

    func lockSlot(_ slot: ExamSlot) async {
        guard permissionChecker.can(.editSchedules) else {
            error = "You don't have permission to edit schedules"
            return
        }

        do {
            try await scheduleRepository.lockExamSlot(id: slot.id)
            await loadData()
            successMessage = "Exam slot locked"
        } catch {
            self.error = "Failed to lock slot: \(error.localizedDescription)"
        }
    }

    func unlockSlot(_ slot: ExamSlot) async {
        guard permissionChecker.can(.editSchedules) else {
            error = "You don't have permission to edit schedules"
            return
        }

        do {
            try await scheduleRepository.unlockExamSlot(id: slot.id)
            await loadData()
            successMessage = "Exam slot unlocked"
        } catch {
            self.error = "Failed to unlock slot: \(error.localizedDescription)"
        }
    }

    func swapSlots(_ slot1: ExamSlot, _ slot2: ExamSlot) async {
        guard permissionChecker.can(.editSchedules) else {
            error = "You don't have permission to edit schedules"
            return
        }

        do {
            try await scheduleRepository.swapExamSlots(slot1Id: slot1.id, slot2Id: slot2.id)
            await loadData()
            successMessage = "Exam slots swapped"
        } catch {
            self.error = "Failed to swap slots: \(error.localizedDescription)"
        }
    }

    // MARK: - Computed Properties

    var filteredSlots: [ExamSlot] {
        examSlots.filter { slot in
            // Find the exam session for this slot
            guard let session = examSessions.first(where: { $0.id == slot.examSessionId }) else {
                return false
            }
            return session.examNumber == selectedExamNumber
        }
    }

    var scheduledCount: Int {
        filteredSlots.filter { $0.isScheduled }.count
    }

    var unscheduledCount: Int {
        filteredSlots.filter { !$0.isScheduled }.count
    }

    var lockedCount: Int {
        filteredSlots.filter { $0.isLocked }.count
    }
}
