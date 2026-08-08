import AppKit
import Combine
import SwiftUI

/// AppKit status item so the free-space bar keeps green/orange/red in the menu bar.
@MainActor
final class StatusItemController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private let monitor: DiskSpaceMonitor
    private let store: CleanupStore
    private let mediaStore: MediaCaptureStore
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    init(monitor: DiskSpaceMonitor, store: CleanupStore, mediaStore: MediaCaptureStore) {
        self.monitor = monitor
        self.store = store
        self.mediaStore = mediaStore
        super.init()
        setup()
    }

    private func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(togglePanel(_:))
            button.sendAction(on: [.leftMouseUp])
        }

        refreshImage()

        Publishers.CombineLatest3(monitor.$freeFraction, monitor.$level, monitor.$freeSpaceLabel)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.refreshImage()
            }
            .store(in: &cancellables)
    }

    private func refreshImage() {
        let image = monitor.makeMenuBarImage()
        image.isTemplate = false
        statusItem?.button?.image = image
        statusItem?.button?.toolTip =
            "\(monitor.freeSpaceLabel) free · \(monitor.freePercentLabel) remaining · \(monitor.level.label)"
    }

    @objc private func togglePanel(_ sender: Any?) {
        if panel?.isVisible == true {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem?.button else { return }

        closePanel()
        mediaStore.closeBrowser()

        let root = CleanupPopoverView()
            .environmentObject(monitor)
            .environmentObject(store)
            .environmentObject(mediaStore)
            .frame(width: 420, height: 560)

        let hosting = NSHostingController(rootView: root)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 420, height: 560)
        hosting.view.wantsLayer = true
        hosting.view.layer?.cornerRadius = 10
        hosting.view.layer?.masksToBounds = true

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.contentViewController = hosting
        newPanel.isReleasedWhenClosed = false

        position(panel: newPanel, under: button)
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = newPanel

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.handleOutsideClick()
            }
        }
    }

    private func handleOutsideClick() {
        guard let panel, panel.isVisible else { return }
        let click = NSEvent.mouseLocation
        if panel.frame.contains(click) { return }
        if let button = statusItem?.button, let window = button.window {
            let buttonScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
            if buttonScreen.contains(click) { return }
        }
        closePanel()
    }

    private func position(panel: NSPanel, under button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelSize = panel.frame.size
        var origin = NSPoint(
            x: buttonRect.midX - panelSize.width / 2,
            y: buttonRect.minY - panelSize.height - 6
        )
        if let screen = buttonWindow.screen ?? NSScreen.main {
            origin.x = min(
                max(origin.x, screen.visibleFrame.minX + 8),
                screen.visibleFrame.maxX - panelSize.width - 8
            )
            if origin.y < screen.visibleFrame.minY {
                origin.y = buttonRect.maxY + 6
            }
        }
        panel.setFrameOrigin(origin)
    }

    private func closePanel() {
        panel?.orderOut(nil)
        panel = nil
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}
