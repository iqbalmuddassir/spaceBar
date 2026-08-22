import AppKit
import SnapshotTesting
import SwiftUI
import XCTest
@testable import SpaceBar

@MainActor
final class SettingsSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        NSApp.setActivationPolicy(.regular)
        LiquidGlassRuntime.testOverride = false
    }

    override func tearDown() {
        LiquidGlassRuntime.testOverride = nil
        super.tearDown()
    }

    func testSettingsAppearanceTab() {
        assertSettingsTab(AppearanceSettingsTab(), named: "settings-appearance")
    }

    func testSettingsThresholdsTab() {
        assertSettingsTab(ThresholdSettingsTab(), named: "settings-thresholds")
    }

    func testSettingsScanningTab() {
        assertSettingsTab(ScanningSettingsTab(), named: "settings-scanning")
    }

    func testPanelSettings() {
        let settings = SnapshotFixtures.settings()
        let monitor = SnapshotFixtures.diskMonitor(for: .good, settings: settings)
        let root = PanelSettingsView { }
            .environmentObject(settings)
            .environmentObject(monitor)
            .frame(width: SnapshotFixtures.panelSize.width, height: SnapshotFixtures.panelSize.height)

        assertSnapshot(
            of: SnapshotExport.renderedImage(from: SnapshotExport.makeHostedPanel(rootView: root)),
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: "panel-settings"
        )
    }

    /// Sections are snapshotted individually so a change in one does not re-record all three.
    /// Width matches the panel, since that is the only place they render.
    private func assertSettingsTab(_ tab: some View, named name: String) {
        let settings = SnapshotFixtures.settings()
        let monitor = SnapshotFixtures.diskMonitor(for: .good, settings: settings)
        let root = tab
            .environmentObject(settings)
            .environmentObject(monitor)
            .padding(16)
            .frame(width: SnapshotFixtures.panelSize.width, alignment: .topLeading)

        assertSnapshot(
            of: SnapshotExport.renderedImage(from: SnapshotExport.makeHostedPanel(rootView: root)),
            as: .image(precision: 0.98, perceptualPrecision: 0.98),
            named: name
        )
    }
}
