//
//  ClementimeApp.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import CoreData
import Combine

@main
struct ClementimeApp: App {
    // Core Data persistence controller
    @StateObject private var persistenceController = PersistenceController.shared

    // App state management
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // Add custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Course...") {
                    appState.showCourseCreator = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .defaultSize(width: 1200, height: 800)
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var currentCourse: Course?
    @Published var currentUser: TAUser?
    @Published var showCourseCreator = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Permission checker (lazy initialized when user/course are set)
    var permissionChecker: PermissionChecker? {
        guard let user = currentUser, let course = currentCourse else {
            return nil
        }
        return PermissionChecker(currentUser: user, course: course)
    }
}
