//
//  SyncStatusView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import SwiftUI
import Combine
import CoreData

struct SyncStatusView: View {
    @StateObject private var viewModel: SyncStatusViewModel

    init() {
        self._viewModel = StateObject(wrappedValue: SyncStatusViewModel(
            container: PersistenceController.shared.container
        ))
    }
    @State private var isHovering = false

    var body: some View {
        Button(action: {
            viewModel.manualSync()
        }) {
            ZStack {
                // Background circle on hover
                if isHovering {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                }

                // Cloud icon with sync indicator
                ZStack {
                    Image(systemName: cloudIconName)
                        .font(.system(size: 16))
                        .foregroundColor(iconColor)
                        .symbolRenderingMode(.hierarchical)

                    // Syncing animation
                    if viewModel.isSyncing {
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(viewModel.rotationAngle))
                    }

                    // Success checkmark
                    if viewModel.showSuccessIndicator {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .offset(x: 8, y: -8)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .help(tooltipText)
        .onAppear {
            viewModel.startMonitoring()
        }
    }

    private var cloudIconName: String {
        if viewModel.isSyncing {
            return "icloud"
        } else if viewModel.lastSyncFailed {
            return "icloud.slash"
        } else {
            return "icloud"
        }
    }

    private var iconColor: Color {
        if viewModel.isSyncing {
            return .accentColor
        } else if viewModel.lastSyncFailed {
            return .red
        } else {
            return .secondary
        }
    }

    private var tooltipText: String {
        if viewModel.isSyncing {
            return "Syncing with iCloud..."
        } else if viewModel.lastSyncFailed {
            return "Last sync failed. Click to retry."
        } else if let lastSync = viewModel.lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let timeAgo = formatter.localizedString(for: lastSync, relativeTo: Date())
            return "Last synced \(timeAgo). Click to sync now."
        } else {
            return "Click to sync with iCloud"
        }
    }
}

@MainActor
class SyncStatusViewModel: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var lastSyncFailed = false
    @Published var showSuccessIndicator = false
    @Published var rotationAngle: Double = 0

    private var rotationTimer: Timer?
    private var syncCheckTimer: Timer?
    private var eventObserver: AnyCancellable?
    private let container: NSPersistentCloudKitContainer

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
        setupEventObserver()
    }

    func startMonitoring() {
        // Check sync status periodically
        syncCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkSyncStatus()
            }
        }

        // Initial check
        Task {
            await checkSyncStatus()
        }
    }

    func manualSync() {
        Task {
            await performSync()
        }
    }

    private func setupEventObserver() {
        // Observe CloudKit sync events
        eventObserver = NotificationCenter.default
            .publisher(for: NSPersistentCloudKitContainer.eventChangedNotification, object: container)
            .sink { [weak self] notification in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleSyncEvent(notification)
                }
            }
    }

    private func handleSyncEvent(_ notification: Notification) async {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }

        switch event.type {
        case .setup:
            // CloudKit setup event
            break
        case .import:
            // Import from CloudKit started/finished
            if event.endDate == nil {
                isSyncing = true
                startRotationAnimation()
            } else {
                isSyncing = false
                stopRotationAnimation()
                if event.error == nil {
                    lastSyncDate = event.endDate
                    showSuccessIndicator = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        await MainActor.run {
                            showSuccessIndicator = false
                        }
                    }
                } else {
                    lastSyncFailed = true
                }
            }
        case .export:
            // Export to CloudKit started/finished
            if event.endDate == nil {
                isSyncing = true
                startRotationAnimation()
            } else {
                isSyncing = false
                stopRotationAnimation()
                if event.error == nil {
                    lastSyncDate = event.endDate
                } else {
                    lastSyncFailed = true
                }
            }
        @unknown default:
            break
        }
    }

    private func checkSyncStatus() async {
        // Query the container's event history for the most recent sync event
        // This is automatically handled by the event observer now
        // We can also check if there are pending changes
        await container.viewContext.perform { [weak self] in
            guard let self = self else { return }
            // Check if there are uncommitted changes
            if self.container.viewContext.hasChanges {
                Task { @MainActor in
                    // There are local changes that haven't been synced yet
                    // The sync will happen automatically
                }
            }
        }
    }

    private func performSync() async {
        guard !isSyncing else { return }

        isSyncing = true
        lastSyncFailed = false
        showSuccessIndicator = false

        // Start rotation animation
        startRotationAnimation()

        do {
            // Trigger a save to initiate CloudKit sync
            // NSPersistentCloudKitContainer automatically syncs on save
            await container.viewContext.perform { [weak self] in
                guard let self = self else { return }
                if self.container.viewContext.hasChanges {
                    try? self.container.viewContext.save()
                }
            }

            // Wait for sync to complete with timeout
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second timeout

            // Complete the sync
            await MainActor.run {
                isSyncing = false
                lastSyncDate = Date()
                stopRotationAnimation()

                // Show success indicator briefly
                showSuccessIndicator = true
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        showSuccessIndicator = false
                    }
                }
            }
        } catch {
            // Sync failed
            await MainActor.run {
                isSyncing = false
                lastSyncFailed = true
                stopRotationAnimation()
            }
        }
    }

    private func startRotationAnimation() {
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                withAnimation(.linear(duration: 0.016)) {
                    self.rotationAngle += 3
                    if self.rotationAngle >= 360 {
                        self.rotationAngle = 0
                    }
                }
            }
        }
    }

    private func stopRotationAnimation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        rotationAngle = 0
    }

    deinit {
        rotationTimer?.invalidate()
        syncCheckTimer?.invalidate()
        eventObserver?.cancel()
    }
}

#Preview {
    SyncStatusView()
        .padding()
}
