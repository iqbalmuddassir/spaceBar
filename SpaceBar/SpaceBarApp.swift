import AppKit
import SwiftUI

@main
struct SpaceBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar only app; status item is created in AppDelegate.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let diskMonitor = DiskSpaceMonitor()
    private let cleanupStore = CleanupStore()
    private let mediaStore = MediaCaptureStore()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(
            monitor: diskMonitor,
            store: cleanupStore,
            mediaStore: mediaStore
        )
        cleanupStore.startInitialScan()
        mediaStore.scan()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
