//
//  StudentsViewModel.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import Combine

@MainActor
class StudentsViewModel: ObservableObject {
    @Published var students: [Student] = []
    @Published var filteredStudents: [Student] = []
    @Published var sections: [Section] = []
    @Published var cohorts: [Cohort] = []
    @Published var examSlots: [ExamSlot] = []
    @Published var searchQuery = "" {
        didSet {
            filterStudents()
        }
    }
    @Published var isLoading = false
    @Published var isImporting = false
    @Published var error: String?
    @Published var successMessage: String?
    @Published var showImportSheet = false
    @Published var canManageStudents = false

    private let course: Course
    private let studentRepository: StudentRepository
    private let permissionChecker: PermissionChecker
    private let sectionRepository = PersistenceController.shared.sectionRepository
    private let cohortRepository = PersistenceController.shared.cohortRepository
    private let scheduleRepository = PersistenceController.shared.scheduleRepository

    init(
        course: Course,
        studentRepository: StudentRepository,
        permissionChecker: PermissionChecker
    ) {
        self.course = course
        self.studentRepository = studentRepository
        self.permissionChecker = permissionChecker

        self.canManageStudents = permissionChecker.can(.manageStudents)
    }

    func loadStudents() async {
        isLoading = true
        error = nil

        do {
            students = try await studentRepository.fetchStudents(courseId: course.id)
            sections = try await sectionRepository.fetchSections(courseId: course.id)
            cohorts = try await cohortRepository.fetchCohorts(courseId: course.id)
            examSlots = try await scheduleRepository.fetchExamSlots(courseId: course.id)
            filterStudents()
        } catch {
            self.error = "Failed to load students: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func importRoster(from url: URL, randomlyAssignCohorts: Bool = false, clearExistingStudents: Bool = false) async {
        guard permissionChecker.can(.manageStudents) else {
            error = "You don't have permission to manage students"
            return
        }

        isImporting = true
        error = nil
        successMessage = nil

        do {
            // Load sections and cohorts first to ensure import sees the latest data
            sections = try await sectionRepository.fetchSections(courseId: course.id)
            cohorts = try await cohortRepository.fetchCohorts(courseId: course.id)

            // Clear existing students if requested
            if clearExistingStudents {
                try await studentRepository.deleteAllStudents(courseId: course.id)
            }

            let result = try await studentRepository.importStudents(from: url, courseId: course.id, randomlyAssignCohorts: randomlyAssignCohorts)

            // Debug logging
            print("Import result: \(result.successCount) succeeded, \(result.failureCount) failed")
            print("Errors: \(result.errors)")

            // Reload students first
            await loadStudents()

            // Show results
            if result.successCount == 0 && result.failureCount == 0 {
                error = "No students were imported. Please check your CSV file format."
            } else if !result.errors.isEmpty {
                let errorMessages = result.errors.prefix(10).map { error in
                    "Row \(error.row): \(error.reason)" + (error.studentName != nil ? " (\(error.studentName!))" : "")
                }
                let moreErrors = result.errors.count > 10 ? "\n...and \(result.errors.count - 10) more errors" : ""

                if result.successCount > 0 {
                    error = "Imported \(result.successCount) students with \(result.failureCount) errors:\n" + errorMessages.joined(separator: "\n") + moreErrors
                } else {
                    error = "Import failed with \(result.failureCount) errors:\n" + errorMessages.joined(separator: "\n") + moreErrors
                }
            } else if result.successCount > 0 {
                successMessage = "Successfully imported \(result.successCount) student\(result.successCount == 1 ? "" : "s")"
            }
        } catch {
            self.error = "Failed to import roster: \(error.localizedDescription)"
        }

        isImporting = false
    }

    func deleteStudent(_ student: Student) async {
        guard permissionChecker.can(.manageStudents) else {
            error = "You don't have permission to manage students"
            return
        }

        do {
            try await studentRepository.deleteStudent(id: student.id)
            await loadStudents()
            successMessage = "Student deleted"
        } catch {
            self.error = "Failed to delete student: \(error.localizedDescription)"
        }
    }

    func randomlyReassignCohorts() async {
        guard permissionChecker.can(.manageStudents) else {
            error = "You don't have permission to manage students"
            return
        }

        isLoading = true
        error = nil
        successMessage = nil

        do {
            // First, fix any students with invalid cohort assignments
            let fixedCount = try await studentRepository.fixInvalidCohortAssignments(courseId: course.id)

            // Then reassign all students to cohorts
            let count = try await studentRepository.randomlyReassignCohorts(courseId: course.id)

            await loadStudents()

            if fixedCount > 0 {
                successMessage = "Fixed \(fixedCount) invalid assignment\(fixedCount == 1 ? "" : "s") and reassigned \(count) student\(count == 1 ? "" : "s") to cohorts"
            } else {
                successMessage = "Successfully reassigned \(count) student\(count == 1 ? "" : "s") to cohorts"
            }
        } catch {
            self.error = "Failed to reassign cohorts: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Filtering

    private func filterStudents() {
        if searchQuery.isEmpty {
            filteredStudents = students
        } else {
            filteredStudents = students.filter { student in
                student.fullName.localizedCaseInsensitiveContains(searchQuery) ||
                student.email.localizedCaseInsensitiveContains(searchQuery) ||
                student.sisUserId.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    // MARK: - Computed Properties

    var activeStudentsCount: Int {
        students.filter { $0.isActive }.count
    }

    var inactiveStudentsCount: Int {
        students.filter { !$0.isActive }.count
    }

    var totalStudentsCount: Int {
        students.count
    }

    func sectionName(for sectionId: UUID) -> String {
        sections.first(where: { $0.id == sectionId })?.name ?? "Unknown Section"
    }

    func cohortName(for cohortId: UUID) -> String {
        cohorts.first(where: { $0.id == cohortId })?.name ?? "Unknown Cohort"
    }
}
