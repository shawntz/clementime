//
//  StudentsViewModel.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation
import Combine

@MainActor
class StudentsViewModel: ObservableObject {
    @Published var students: [Student] = []
    @Published var filteredStudents: [Student] = []
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
            filterStudents()
        } catch {
            self.error = "Failed to load students: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func importRoster(from url: URL) async {
        guard permissionChecker.can(.manageStudents) else {
            error = "You don't have permission to manage students"
            return
        }

        isImporting = true
        error = nil
        successMessage = nil

        do {
            let result = try await studentRepository.importStudents(from: url, courseId: course.id)

            if !result.errors.isEmpty {
                error = "Import completed with errors:\n" + result.errors.joined(separator: "\n")
            } else {
                successMessage = "Successfully imported \(result.created) new students and updated \(result.updated) existing students"
            }

            await loadStudents()
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

    var totalStudentsCount: Int {
        students.count
    }
}
