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

    func testBuildFilesBrowser_macOS14() {
        assertReviewBrowser(
            for: .projectBuildFiles,
            glass: false,
            named: "build-files-browser-macos14",
            exportDocsAs: "spacebar-build-files-browser",
            testName: #function
        )
    }

    func testBuildFilesBrowser_macOS26() throws {
        try requireLiquidGlassHost()
        assertReviewBrowser(
            for: .projectBuildFiles,
            glass: true,
            named: "build-files-browser-macos26",
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

    func testBatchCleanConfirmDialog() {
        LiquidGlassRuntime.withChrome(false) {
            let target = CleanTarget(
                id: "xcode-derived",
                name: "Xcode DerivedData",
                subtitle: "~/Library/Developer/Xcode/DerivedData",
                safetyNote: "Xcode will rebuild DerivedData on the next build.",
                strategy: .deletePaths([]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
            let result = TargetScanResult(
                target: target,
                byteSize: 1_500_000_000,
                phase: .ready
            )
            let root = ZStack {
                Color(nsColor: .windowBackgroundColor)
                BatchCleanConfirmOverlay(
                    targets: [result],
                    totalBytes: result.byteSize,
                    onCancel: { },
                    onConfirm: { }
                )
            }
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

            assertSnapshot(
                of: SnapshotExport.makeHostedPanel(rootView: root),
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "batch-clean-confirm-dialog",
                testName: #function
            )
        }
    }

    func testAutomationAccessDialog() {
        LiquidGlassRuntime.withChrome(false) {
            let root = ZStack {
                Color(nsColor: .windowBackgroundColor)
                AutomationAccessOverlay(isPresented: .constant(true))
            }
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

            assertSnapshot(
                of: SnapshotExport.makeHostedPanel(rootView: root),
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "automation-access-dialog",
                testName: #function
            )
        }
    }

    func testFullDiskAccessDialog() {
        LiquidGlassRuntime.withChrome(false) {
            let root = ZStack {
                Color(nsColor: .windowBackgroundColor)
                FullDiskAccessOverlay(isPresented: .constant(true))
            }
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

            assertSnapshot(
                of: SnapshotExport.makeHostedPanel(rootView: root),
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "full-disk-access-dialog",
                testName: #function
            )
        }
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

    func testCleanupPanelMapLayout() {
        LiquidGlassRuntime.withChrome(false) {
            let settings = SnapshotFixtures.settings()
            settings.layout = .map
            let hosting = makeCleanupPanel(for: .good, settings: settings)
            assertSnapshot(
                of: hosting,
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "cleanup-panel-map"
            )
            SnapshotExport.exportHiResSnapshot(from: hosting, named: "spacebar-panel-map")
        }
    }

    func testCleanupPanelLedgerLayout() {
        LiquidGlassRuntime.withChrome(false) {
            let settings = SnapshotFixtures.settings()
            settings.layout = .ledger
            assertSnapshot(
                of: makeCleanupPanel(for: .good, settings: settings),
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "cleanup-panel-ledger"
            )
        }
    }
}

extension PanelSnapshotTests {
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

    private func makeCleanupPanel(
        for freeSpaceCase: SnapshotFixtures.FreeSpaceCase,
        settings: AppSettings? = nil
    ) -> NSView {
        let settings = settings ?? SnapshotFixtures.settings()
        // Otherwise a real scan of the recording host replaces the fixture rows mid-snapshot.
        settings.rescanOnOpen = false
        settings.hasSeenFirstRunPrimer = true
        let monitor = SnapshotFixtures.diskMonitor(for: freeSpaceCase, settings: settings)
        let store = SnapshotFixtures.cleanupStore()
        let reviewCoordinator = SnapshotFixtures.reviewCoordinator()

        let root = CleanupPopoverView()
            .environmentObject(monitor)
            .environmentObject(store)
            .environmentObject(reviewCoordinator)
            .environmentObject(settings)
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

        return SnapshotExport.makeHostedPanel(rootView: root)
    }

    private func makeReviewBrowser(for category: ReviewableFileCategory) -> NSView {
        let settings = SnapshotFixtures.settings()
        let monitor = SnapshotFixtures.diskMonitor(for: .good, settings: settings)
        let store = SnapshotFixtures.reviewStore(for: category)
        store.showBrowser = true
        store.selectAll()

        let root = ReviewableFilesBrowserView(store: store)
            .environmentObject(monitor)
            .environmentObject(settings)
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

        return SnapshotExport.makeHostedPanel(rootView: root)
    }
}
