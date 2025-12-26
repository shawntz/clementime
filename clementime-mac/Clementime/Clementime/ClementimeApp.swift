//
//  ClementimeApp.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI
import AppKit
import CoreData
import Combine

@main
struct ClementimeApp: App {
    // Core Data persistence controller
    @StateObject private var persistenceController = PersistenceController.shared

    // App state management
    @StateObject private var appState = AppState()

    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // Replace About menu item
            CommandGroup(replacing: .appInfo) {
                Button("About ClemenTime") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                                string: "Native macOS oral exam scheduler\nwith CloudKit sync and offline support.",
                                attributes: [
                                    .font: NSFont.systemFont(ofSize: 11),
                                    .foregroundColor: NSColor.secondaryLabelColor
                                ]
                            ),
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© Shawn Schwartz, 2025"
                        ]
                    )
                }
            }

            // Add custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Course...") {
                    appState.showCourseCreator = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            // Add Help menu items
            CommandGroup(replacing: .help) {
                Button("ClemenTime Documentation") {
                    if let url = URL(string: "https://github.com/shawntz/clementime/blob/main/clementime-mac/README.md") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut("/", modifiers: .command)

                Button("GitHub Repository") {
                    if let url = URL(string: "https://github.com/shawntz/clementime") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button("Report an Issue") {
                    if let url = URL(string: "https://github.com/shawntz/clementime/issues/new") {
                        NSWorkspace.shared.open(url)
                    }
                }
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
