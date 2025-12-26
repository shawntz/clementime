//
//  DependencyContainer.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation

class DependencyContainer {
    static let shared = DependencyContainer()

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Repositories

    var courseRepository: CourseRepository {
        persistence.courseRepository
    }

    var studentRepository: StudentRepository {
        persistence.studentRepository
    }

    var scheduleRepository: ScheduleRepository {
        persistence.scheduleRepository
    }

    var cohortRepository: CohortRepository {
        persistence.cohortRepository
    }

    var sectionRepository: SectionRepository {
        persistence.sectionRepository
    }

    var examSessionRepository: ExamSessionRepository {
        persistence.examSessionRepository
    }

    var constraintRepository: ConstraintRepository {
        persistence.constraintRepository
    }

    var recordingRepository: RecordingRepository {
        persistence.recordingRepository
    }

    var taUserRepository: TAUserRepository {
        persistence.taUserRepository
    }

    // MARK: - Use Cases

    func makeGenerateScheduleUseCase() -> GenerateScheduleUseCase {
        GenerateScheduleUseCase(
            courseRepository: courseRepository,
            cohortRepository: cohortRepository,
            studentRepository: studentRepository,
            sectionRepository: sectionRepository,
            examSessionRepository: examSessionRepository,
            constraintRepository: constraintRepository,
            scheduleRepository: scheduleRepository
        )
    }

    func makeExportScheduleUseCase() -> ExportScheduleUseCase {
        ExportScheduleUseCase(
            courseRepository: courseRepository,
            studentRepository: studentRepository,
            sectionRepository: sectionRepository,
            scheduleRepository: scheduleRepository,
            examSessionRepository: examSessionRepository
        )
    }

    func makeCreateCourseUseCase() -> CreateCourseUseCase {
        CreateCourseUseCase(
            courseRepository: courseRepository,
            cohortRepository: cohortRepository,
            examSessionRepository: examSessionRepository
        )
    }

    func makeShareCourseUseCase() -> ShareCourseUseCase {
        ShareCourseUseCase(
            courseRepository: courseRepository,
            taUserRepository: taUserRepository
        )
    }

    // MARK: - Services

    var currentUserService: CurrentUserService {
        CurrentUserService.shared
    }

    // MARK: - Permission Checker

    func makePermissionChecker(for course: Course) -> PermissionChecker {
        // For now, use a default admin user
        // In a real implementation, this would use the current logged-in user
        let currentUser = currentUserService.currentUser ?? TAUser(
            id: currentUserService.currentUserId,
            courseId: course.id,
            firstName: "Admin",
            lastName: "User",
            email: "admin@example.com",
            username: "admin",
            role: .admin,
            customPermissions: Permission.allPermissions(),
            isActive: true
        )

        return PermissionChecker(currentUser: currentUser, course: course)
    }
}
