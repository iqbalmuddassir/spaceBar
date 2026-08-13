import AppKit
import Combine
import SwiftUI

@main
struct SpaceBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private lazy var diskMonitor = DiskSpaceMonitor(settings: settings)
    private let cleanupStore = CleanupStore()
    private let reviewCoordinator = ReviewableFilesCoordinator()
    private var statusItemController: StatusItemController?
    private var settingsObserver: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(
            monitor: diskMonitor,
            store: cleanupStore,
            reviewCoordinator: reviewCoordinator,
            settings: settings
        )
        cleanupStore.excludedTargetIDs = settings.excludedTargetIDs
        reviewCoordinator.excludedIDs = settings.excludedTargetIDs
        settingsObserver = settings.$excludedTargetIDs.sink { [weak self] excluded in
            self?.cleanupStore.excludedTargetIDs = excluded
            self?.reviewCoordinator.excludedIDs = excluded
        }
        cleanupStore.startInitialScan()
        reviewCoordinator.scanAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
