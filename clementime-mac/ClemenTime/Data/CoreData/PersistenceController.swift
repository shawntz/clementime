//
//  PersistenceController.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import CoreData
import CloudKit
import Combine

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    // MARK: - Cloud Kit Share Manager

    lazy var shareManager: CloudKitShareManager = {
        CloudKitShareManager(persistentContainer: container)
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
        CoreDataRecordingRepository(persistentContainer: container)
    }()

    lazy var taUserRepository: TAUserRepository = {
        CoreDataTAUserRepository(persistentContainer: container)
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Clementime")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure CloudKit container
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description")
            }

            // TEMPORARY: Disable CloudKit sync until entitlements are configured
            // TODO: Re-enable after setting up CloudKit in Xcode capabilities
            description.cloudKitContainerOptions = nil

            // Enable history tracking for future CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

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

        // Observe remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    @objc
    private func handleRemoteChange(_ notification: Notification) {
        // Merge remote changes
        container.viewContext.perform {
            // Changes will be automatically merged due to automaticallyMergesChangesFromParent
            print("Remote changes received from CloudKit")
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
        // TODO: Add sample course, students, etc.

        controller.save()
        return controller
    }()
}
