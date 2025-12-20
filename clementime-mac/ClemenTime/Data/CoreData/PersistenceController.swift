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

    // MARK: - Cloud Kit Share Manager

    lazy var shareManager: CloudKitShareManager? = {
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

            // Enable CloudKit sync
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.shawnschwartz.clementime")
            description.cloudKitContainerOptions = cloudKitOptions

            // Enable history tracking for CloudKit sync
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

        // Observe remote changes from CloudKit
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
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
        // TODO: Add sample course, students, etc.

        controller.save()
        return controller
    }()
}
