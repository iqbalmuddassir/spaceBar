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
        LiquidGlassRuntime.testOverride = nil
    }

    override func tearDown() {
        LiquidGlassRuntime.testOverride = nil
        super.tearDown()
    }

    func testCleanupPanelGood_macOS14() {
        assertCleanupPanel(
            for: .good,
            glass: false,
            named: "cleanup-panel-good-macos14",
            exportDocs: true,
            testName: #function
        )
    }

    func testCleanupPanelLow_macOS14() {
        assertCleanupPanel(
            for: .low,
            glass: false,
            named: "cleanup-panel-low-macos14",
            exportDocs: true,
            testName: #function
        )
    }

    func testCleanupPanelCritical_macOS14() {
        assertCleanupPanel(
            for: .critical,
            glass: false,
            named: "cleanup-panel-critical-macos14",
            exportDocs: true,
            testName: #function
        )
    }

    func testMediaBrowser_macOS14() {
        assertReviewBrowser(
            for: .screenshotsAndRecordings,
            glass: false,
            named: "media-browser-macos14",
            exportDocsAs: "spacebar-media-browser",
            testName: #function
        )
    }

    func testInstallerBrowser_macOS14() {
        assertReviewBrowser(
            for: .installerPackages,
            glass: false,
            named: "installer-browser-macos14",
            exportDocsAs: "spacebar-installer-browser",
            testName: #function
        )
    }

    func testCleanupPanelGood_macOS26() throws {
        try requireLiquidGlassHost()
        assertCleanupPanel(
            for: .good,
            glass: true,
            named: "cleanup-panel-good-macos26",
            testName: #function
        )
    }

    func testCleanupPanelLow_macOS26() throws {
        try requireLiquidGlassHost()
        assertCleanupPanel(
            for: .low,
            glass: true,
            named: "cleanup-panel-low-macos26",
            testName: #function
        )
    }

    func testCleanupPanelCritical_macOS26() throws {
        try requireLiquidGlassHost()
        assertCleanupPanel(
            for: .critical,
            glass: true,
            named: "cleanup-panel-critical-macos26",
            testName: #function
        )
    }

    func testMediaBrowser_macOS26() throws {
        try requireLiquidGlassHost()
        assertReviewBrowser(
            for: .screenshotsAndRecordings,
            glass: true,
            named: "media-browser-macos26",
            testName: #function
        )
    }

    func testInstallerBrowser_macOS26() throws {
        try requireLiquidGlassHost()
        assertReviewBrowser(
            for: .installerPackages,
            glass: true,
            named: "installer-browser-macos26",
            testName: #function
        )
    }

    func testMenuBarPillGood() {
        let image = SnapshotFixtures.diskMonitor(for: .good).makeMenuBarImage()
        assertSnapshot(
            of: image,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "menu-bar-pill-good"
        )
        SnapshotExport.exportREADMESnapshot(image: image, named: "spacebar-pill-good")
        SnapshotExport.exportHiResSnapshot(image: image, named: "spacebar-pill-good")
    }

    func testMenuBarPillLow() {
        let image = SnapshotFixtures.diskMonitor(for: .low).makeMenuBarImage()
        assertSnapshot(
            of: image,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "menu-bar-pill-low"
        )
        SnapshotExport.exportREADMESnapshot(image: image, named: "spacebar-pill-low")
        SnapshotExport.exportHiResSnapshot(image: image, named: "spacebar-pill-low")
    }

    func testMenuBarPillCritical() {
        let image = SnapshotFixtures.diskMonitor(for: .critical).makeMenuBarImage()
        assertSnapshot(
            of: image,
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "menu-bar-pill-critical"
        )
        SnapshotExport.exportREADMESnapshot(image: image, named: "spacebar-pill-critical")
        SnapshotExport.exportHiResSnapshot(image: image, named: "spacebar-pill-critical")
    }

    private func requireLiquidGlassHost() throws {
        guard #available(macOS 26, *) else {
            throw XCTSkip("Liquid Glass snapshots require macOS 26+")
        }
    }

    private func assertCleanupPanel(
        for freeSpaceCase: SnapshotFixtures.FreeSpaceCase,
        glass: Bool,
        named name: String,
        exportDocs: Bool = false,
        testName: String
    ) {
        LiquidGlassRuntime.withChrome(glass) {
            let hosting = makeCleanupPanel(for: freeSpaceCase)
            assertSnapshot(
                of: hosting,
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: name,
                testName: testName
            )
            if exportDocs {
                let docsName = "spacebar-panel-\(freeSpaceCase.snapshotName)"
                SnapshotExport.exportREADMESnapshot(from: hosting, named: docsName)
                SnapshotExport.exportHiResSnapshot(from: hosting, named: docsName)
                if freeSpaceCase == .good {
                    SnapshotExport.exportREADMESnapshot(from: hosting, named: "spacebar-panel")
                    SnapshotExport.exportHiResSnapshot(from: hosting, named: "spacebar-panel")
                }
            }
        }
    }

    private func assertReviewBrowser(
        for category: ReviewableFileCategory,
        glass: Bool,
        named name: String,
        exportDocsAs docsName: String? = nil,
        testName: String
    ) {
        LiquidGlassRuntime.withChrome(glass) {
            let hosting = makeReviewBrowser(for: category)
            assertSnapshot(
                of: hosting,
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: name,
                testName: testName
            )
            if let docsName {
                SnapshotExport.exportHiResSnapshot(from: hosting, named: docsName)
            }
        }
    }

    private func makeCleanupPanel(for freeSpaceCase: SnapshotFixtures.FreeSpaceCase) -> NSView {
        let monitor = SnapshotFixtures.diskMonitor(for: freeSpaceCase)
        let store = SnapshotFixtures.cleanupStore()
        let reviewCoordinator = SnapshotFixtures.reviewCoordinator()

        let root = CleanupPopoverView()
            .environmentObject(monitor)
            .environmentObject(store)
            .environmentObject(reviewCoordinator)
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

        return SnapshotExport.makeHostedPanel(rootView: root)
    }

    private func makeReviewBrowser(for category: ReviewableFileCategory) -> NSView {
        let monitor = SnapshotFixtures.diskMonitor(for: .good)
        let store = SnapshotFixtures.reviewStore(for: category)
        store.showBrowser = true
        store.selectAll()

        let root = ReviewableFilesBrowserView(store: store)
            .environmentObject(monitor)
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

        return SnapshotExport.makeHostedPanel(rootView: root)
    }
}
