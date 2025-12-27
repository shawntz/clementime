//
//  PersistenceController.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import CoreData
import CloudKit
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    private let cloudKitEnabled: Bool

    // MARK: - Cloud Kit Share Manager

    lazy var shareManager: CloudKitShareManager? = {
        guard cloudKitEnabled else {
            return nil
        }
        return CloudKitShareManager(persistentContainer: container)
    }()

    // MARK: - Repositories

    lazy var courseRepository: CourseRepository = {
        CoreDataCourseRepository(persistentContainer: container, shareManager: shareManager)
    }()

    lazy var studentRepository: StudentRepository = {
        CoreDataStudentRepository(persistentContainer: container)
    }()

    lazy var scheduleRepository: ScheduleRepository = {
        CoreDataScheduleRepository(persistentContainer: container)
    }()

    lazy var cohortRepository: CohortRepository = {
        CoreDataCohortRepository(persistentContainer: container)
    }()

    lazy var sectionRepository: SectionRepository = {
        CoreDataSectionRepository(persistentContainer: container)
    }()

    lazy var examSessionRepository: ExamSessionRepository = {
        CoreDataExamSessionRepository(persistentContainer: container)
    }()

    lazy var constraintRepository: ConstraintRepository = {
        CoreDataConstraintRepository(persistentContainer: container)
    }()

    lazy var recordingRepository: RecordingRepository = {
        CoreDataRecordingRepository(persistentContainer: container, cloudKitEnabled: cloudKitEnabled)
    }()

    lazy var taUserRepository: TAUserRepository = {
        CoreDataTAUserRepository(persistentContainer: container)
    }()

    init(inMemory: Bool = false) {
        cloudKitEnabled = Self.isCloudKitEnabled()
        container = NSPersistentCloudKitContainer(name: "Clementime")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure persistent store location
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }

            // Set store URL to Application Support directory (sandboxed location)
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let storeDirectory = appSupportURL.appendingPathComponent("com.shawnschwartz.clementime", isDirectory: true)

            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: storeDirectory.path) {
                try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
            }

            let storeURL = storeDirectory.appendingPathComponent("Clementime.sqlite")
            description.url = storeURL

            print("Core Data store location: \(storeURL.path)")

            if cloudKitEnabled {
                // Enable CloudKit sync
                let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.shawnschwartz.clementime")
                description.cloudKitContainerOptions = cloudKitOptions

                // Enable history tracking for CloudKit sync
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            }

            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }

        // Configure automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        if cloudKitEnabled {
            // Observe remote changes from CloudKit
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRemoteChange(_:)),
                name: .NSPersistentStoreRemoteChange,
                object: container.persistentStoreCoordinator
            )
        }
    }

    private static func isCloudKitEnabled() -> Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: "ClementimeCloudKitEnabled") as? Bool {
            return value
        }
        if let value = Bundle.main.object(forInfoDictionaryKey: "ClementimeCloudKitEnabled") as? String {
            return value.caseInsensitiveCompare("true") == .orderedSame ||
                value.caseInsensitiveCompare("yes") == .orderedSame ||
                value == "1"
        }
        return false
    }

    @objc
    private func handleRemoteChange(_ notification: Notification) {
        container.viewContext.perform {
            print("Remote changes received from CloudKit - data synced")
        }
    }

    // MARK: - Save Context

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Failed to save context: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    // MARK: - Background Context Operations

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    // MARK: - Preview Support

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // Create sample data for previews
        let sampleCourseId = UUID()
        let sampleUserId = UUID()

        // Create sample course
        let courseEntity = CourseEntity(context: context)
        courseEntity.id = sampleCourseId
        courseEntity.name = "PSYCH 10"
        courseEntity.term = "Fall 2025"
        courseEntity.quarterStartDate = Date()
        courseEntity.quarterEndDate = Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date()
        courseEntity.totalExams = 5
        courseEntity.isActive = true
        courseEntity.createdByUserId = sampleUserId
        courseEntity.settingsJSON = "{\"balancedTAScheduling\":false}"
        courseEntity.metadataJSON = "{}"

        // Create default "All Students" cohort
        let allStudentsCohort = CohortEntity(context: context)
        allStudentsCohort.id = UUID()
        allStudentsCohort.courseId = sampleCourseId
        allStudentsCohort.name = "All Students"
        allStudentsCohort.colorHex = "#007AFF"
        allStudentsCohort.sortOrder = 0
        allStudentsCohort.isDefault = true

        // Create sample cohorts
        let cohortA = CohortEntity(context: context)
        cohortA.id = UUID()
        cohortA.courseId = sampleCourseId
        cohortA.name = "Cohort A"
        cohortA.colorHex = "#FF5733"
        cohortA.sortOrder = 1
        cohortA.isDefault = false

        let cohortB = CohortEntity(context: context)
        cohortB.id = UUID()
        cohortB.courseId = sampleCourseId
        cohortB.name = "Cohort B"
        cohortB.colorHex = "#33C1FF"
        cohortB.sortOrder = 2
        cohortB.isDefault = false

        // Create sample sections
        let section1 = SectionEntity(context: context)
        section1.id = UUID()
        section1.courseId = sampleCourseId
        section1.code = "F25-PSYCH-10-01"
        section1.name = "Section 01"
        section1.location = "Building 420, Room 040"
        section1.weekday = 2 // Monday
        section1.startTime = "13:30"
        section1.endTime = "14:50"
        section1.isActive = true

        let section2 = SectionEntity(context: context)
        section2.id = UUID()
        section2.courseId = sampleCourseId
        section2.code = "F25-PSYCH-10-02"
        section2.name = "Section 02"
        section2.location = "Building 420, Room 045"
        section2.weekday = 4 // Wednesday
        section2.startTime = "15:30"
        section2.endTime = "16:50"
        section2.isActive = true

        // Create sample exam sessions
        let examSession1 = ExamSessionEntity(context: context)
        examSession1.id = UUID()
        examSession1.courseId = sampleCourseId
        examSession1.examNumber = 1
        examSession1.weekStartDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        examSession1.theme = "Foundational Questions"
        examSession1.durationMinutes = 7
        examSession1.bufferMinutes = 1

        let examSession2 = ExamSessionEntity(context: context)
        examSession2.id = UUID()
        examSession2.courseId = sampleCourseId
        examSession2.examNumber = 2
        examSession2.weekStartDate = Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
        examSession2.theme = "Methods & Ethics"
        examSession2.durationMinutes = 7
        examSession2.bufferMinutes = 1

        // Create sample students
        for i in 1...15 {
            let student = StudentEntity(context: context)
            student.id = UUID()
            student.courseId = sampleCourseId
            student.sectionId = i % 2 == 0 ? section1.id : section2.id
            student.cohortId = i % 2 == 0 ? cohortA.id : cohortB.id
            student.sisUserId = "student\(i)"
            student.email = "student\(i)@stanford.edu"
            student.fullName = "Student \(i)"
            student.isActive = true
        }

        controller.save()
        return controller
    }()
}
