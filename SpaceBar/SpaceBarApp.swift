import AppKit
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
    private let diskMonitor = DiskSpaceMonitor()
    private let cleanupStore = CleanupStore()
    private let reviewCoordinator = ReviewableFilesCoordinator()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(
            monitor: diskMonitor,
            store: cleanupStore,
            reviewCoordinator: reviewCoordinator
        )
        cleanupStore.startInitialScan()
        reviewCoordinator.scanAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
