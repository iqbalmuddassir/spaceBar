import AppKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import SpaceBar

@MainActor
final class PanelSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NSApp.setActivationPolicy(.regular)
    }

    func testCleanupPanelGood() {
        let hosting = makeCleanupPanel(for: .good)
        assertSnapshot(
            of: hosting,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "cleanup-panel-good"
        )
        exportREADMESnapshot(from: hosting, named: "spacebar-panel-good")
        exportREADMESnapshot(from: hosting, named: "spacebar-panel")
    }

    func testCleanupPanelLow() {
        let hosting = makeCleanupPanel(for: .low)
        assertSnapshot(
            of: hosting,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "cleanup-panel-low"
        )
        exportREADMESnapshot(from: hosting, named: "spacebar-panel-low")
    }

    func testCleanupPanelCritical() {
        let hosting = makeCleanupPanel(for: .critical)
        assertSnapshot(
            of: hosting,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "cleanup-panel-critical"
        )
        exportREADMESnapshot(from: hosting, named: "spacebar-panel-critical")
    }

    func testMenuBarPillGood() {
        let image = SnapshotFixtures.diskMonitor(for: .good).makeMenuBarImage()
        assertSnapshot(
            of: image,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "menu-bar-pill-good"
        )
        exportREADMESnapshot(image: image, named: "spacebar-pill-good")
    }

    func testMenuBarPillLow() {
        let image = SnapshotFixtures.diskMonitor(for: .low).makeMenuBarImage()
        assertSnapshot(
            of: image,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "menu-bar-pill-low"
        )
        exportREADMESnapshot(image: image, named: "spacebar-pill-low")
    }

    func testMenuBarPillCritical() {
        let image = SnapshotFixtures.diskMonitor(for: .critical).makeMenuBarImage()
        assertSnapshot(
            of: image,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "menu-bar-pill-critical"
        )
        exportREADMESnapshot(image: image, named: "spacebar-pill-critical")
    }

    private func makeCleanupPanel(for freeSpaceCase: SnapshotFixtures.FreeSpaceCase) -> NSView {
        let monitor = SnapshotFixtures.diskMonitor(for: freeSpaceCase)
        let store = SnapshotFixtures.cleanupStore()
        let mediaStore = SnapshotFixtures.mediaStore()

        let root = CleanupPopoverView()
            .environmentObject(monitor)
            .environmentObject(store)
            .environmentObject(mediaStore)
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: SnapshotFixtures.panelSize)
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 10
        hosting.layer?.masksToBounds = true
        hosting.layoutSubtreeIfNeeded()
        return hosting
    }

    private func exportREADMESnapshot(from view: NSView, named name: String) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        exportREADMESnapshot(image: image, named: name)
    }

    private func exportREADMESnapshot(image: NSImage, named name: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return }

        let docs = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs", isDirectory: true)
        try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        try? png.write(to: docs.appendingPathComponent("\(name).png"))
    }
}
