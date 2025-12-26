//
//  CourseListViewModel.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation
import Combine

@MainActor
class CourseListViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var showCourseCreator = false

    private let courseRepository: CourseRepository
    private var cancellables = Set<AnyCancellable>()

    init(courseRepository: CourseRepository) {
        self.courseRepository = courseRepository
    }

    func loadCourses() async {
        isLoading = true
        error = nil

        do {
            courses = try await courseRepository.fetchCourses()
        } catch {
            self.error = "Failed to load courses: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deleteCourse(_ course: Course) async {
        do {
            try await courseRepository.deleteCourse(id: course.id)
            await loadCourses()
        } catch {
            self.error = "Failed to delete course: \(error.localizedDescription)"
        }
    }

    func selectCourse(_ course: Course) {
        // This will be handled by the app state
    }
}
