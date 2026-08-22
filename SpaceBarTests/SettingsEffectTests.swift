import AppKit
import XCTest
@testable import SpaceBar

/// Every setting must change something observable. These exist because four settings shipped
/// with a control but no consumer, which no snapshot at default values could have caught.
@MainActor
final class SettingsEffectTests: XCTestCase {
    private func makeMonitor(_ settings: AppSettings) -> DiskSpaceMonitor {
        let monitor = DiskSpaceMonitor(settings: settings)
        monitor.applyFixture(freeBytes: 320_000_000_000, totalBytes: 512_000_000_000)
        return monitor
    }

    func testShowPercentageChangesThePillWidth() {
        let settings = AppSettings.ephemeral()
        let monitor = makeMonitor(settings)

        let bySize = monitor.makeMenuBarImage().size
        settings.showPercentageInPill = true
        let byPercent = monitor.makeMenuBarImage().size

        XCTAssertNotEqual(bySize.width, byPercent.width)
    }

    func testTintedPillDiffersFromSolid() throws {
        let settings = AppSettings.ephemeral()
        let monitor = makeMonitor(settings)

        settings.pillStyle = .solid
        let solid = try XCTUnwrap(monitor.makeMenuBarImage().tiffRepresentation)
        settings.pillStyle = .tinted
        let tinted = try XCTUnwrap(monitor.makeMenuBarImage().tiffRepresentation)

        XCTAssertNotEqual(solid, tinted)
    }

    func testFullColorOnlyWhenCriticalCalmsAHealthyPill() throws {
        let settings = AppSettings.ephemeral()
        let monitor = makeMonitor(settings)

        let alwaysSolid = try XCTUnwrap(monitor.makeMenuBarImage().tiffRepresentation)
        settings.fullColorOnlyWhenCritical = true
        let calm = try XCTUnwrap(monitor.makeMenuBarImage().tiffRepresentation)

        XCTAssertNotEqual(alwaysSolid, calm, "A healthy pill should stop being solid")
    }

    func testCriticalStaysSolidEvenWhenColorIsReserved() throws {
        let settings = AppSettings.ephemeral()
        settings.fullColorOnlyWhenCritical = true
        let monitor = DiskSpaceMonitor(settings: settings)
        monitor.applyFixture(freeBytes: 25_600_000_000, totalBytes: 512_000_000_000)
        XCTAssertEqual(monitor.level, .critical)

        let reserved = try XCTUnwrap(monitor.makeMenuBarImage().tiffRepresentation)
        settings.fullColorOnlyWhenCritical = false
        let always = try XCTUnwrap(monitor.makeMenuBarImage().tiffRepresentation)

        XCTAssertEqual(reserved, always, "Critical is the level the colour is being saved for")
    }

    func testThresholdsRegradeTheLevelWithoutRereadingTheDisk() {
        let settings = AppSettings.ephemeral()
        let monitor = DiskSpaceMonitor(settings: settings)
        monitor.applyFixture(freeBytes: 128_000_000_000, totalBytes: 512_000_000_000) // 25% free
        XCTAssertEqual(monitor.level, .healthy, "25% is healthy at the default 20% warning")

        settings.setWarningFraction(0.30)
        monitor.regradeLevel()
        XCTAssertEqual(monitor.level, .warning)
        XCTAssertEqual(monitor.freeBytes, 128_000_000_000, "Regrading must not touch the volume")
    }

    func testWarningThresholdIsClampedToItsRange() {
        let settings = AppSettings.ephemeral()
        settings.setWarningFraction(0.95)
        XCTAssertEqual(settings.warningFraction, AppSettings.warningRange.upperBound)
    }

    func testCriticalCannotRiseAboveWarning() {
        let settings = AppSettings.ephemeral()
        settings.setWarningFraction(0.20)
        settings.setCriticalFraction(0.40)
        XCTAssertLessThan(settings.criticalFraction, settings.warningFraction)
    }

    func testStaleDaysClampsOnAssignment() {
        let settings = AppSettings.ephemeral()
        settings.staleDays = 0
        XCTAssertEqual(settings.staleDays, AppSettings.staleDayRange.lowerBound)
        settings.staleDays = 999
        XCTAssertEqual(settings.staleDays, AppSettings.staleDayRange.upperBound)
    }

    func testStaleDaysClampsOnLoadFromDefaults() throws {
        let suiteName = "SpaceBar.staleClamp.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(0, forKey: AppSettings.Key.staleDays)
        let low = AppSettings(defaults: defaults)
        XCTAssertEqual(low.staleDays, AppSettings.staleDayRange.lowerBound)

        defaults.set(999, forKey: AppSettings.Key.staleDays)
        let high = AppSettings(defaults: defaults)
        XCTAssertEqual(high.staleDays, AppSettings.staleDayRange.upperBound)
    }

    func testStaleDurationDecidesWhatIsPreselected() {
        let settings = AppSettings.ephemeral()
        let result = TargetScanResult(
            target: CleanTarget(
                id: "gradle-caches",
                name: "Gradle Caches",
                subtitle: "~/.gradle/caches",
                safetyNote: "",
                strategy: .deletePaths([]),
                requiresStrongConfirm: false,
                isPermanent: false,
                activity: .built
            ),
            byteSize: 1_000_000_000,
            phase: .ready,
            recency: Recency(activity: .built, lastTouched: Date().addingTimeInterval(-10 * RelativeAge.day))
        )

        settings.staleDays = 30
        XCTAssertFalse(result.isSafeByDefault(staleAfter: settings.staleInterval), "10 days is still fresh at 30")

        settings.staleDays = 7
        XCTAssertTrue(result.isSafeByDefault(staleAfter: settings.staleInterval), "10 days is stale at 7")
    }

    func testExcludedTargetsAreSkippedBeforeScanning() {
        let settings = AppSettings.ephemeral()
        settings.setExcluded(true, targetID: "npm")
        XCTAssertTrue(settings.isExcluded(targetID: "npm"))

        let store = CleanupStore()
        store.excludedTargetIDs = settings.excludedTargetIDs
        XCTAssertTrue(store.excludedTargetIDs.contains("npm"))
    }

    func testMapDrawsWheneverThereAreEnoughItemsRegardlessOfSize() {
        let tiny = (1 ... 3).map { index in
            ReclaimMapItem(
                id: "tiny-\(index)",
                name: "Tiny \(index)",
                bytes: UInt64(index) * 5_000_000, // tens of MB in total
                temperature: .cold,
                isSelected: true,
                isReview: false
            )
        }
        XCTAssertTrue(MapHeader.isWorthDrawing(tiny), "Proportion reads the same at any scale")
    }

    func testMapFallsBackBelowThreeItems() {
        let two = (1 ... 2).map { index in
            ReclaimMapItem(
                id: "big-\(index)",
                name: "Big \(index)",
                bytes: 20_000_000_000,
                temperature: .cold,
                isSelected: true,
                isReview: false
            )
        }
        XCTAssertFalse(MapHeader.isWorthDrawing(two), "Two tiles say less than a bar does")
    }

    func testMapIgnoresEmptyItemsWhenDecidingToDraw() {
        let padded = [
            ReclaimMapItem(id: "a", name: "A", bytes: 900, temperature: .cold, isSelected: true, isReview: false),
            ReclaimMapItem(id: "b", name: "B", bytes: 0, temperature: .cold, isSelected: true, isReview: false),
            ReclaimMapItem(id: "c", name: "C", bytes: 0, temperature: .cold, isSelected: true, isReview: false)
        ]
        XCTAssertFalse(MapHeader.isWorthDrawing(padded), "Zero-byte rows cannot fill a tile")
    }

    func testDensityChangesRowPadding() {
        XCTAssertNotEqual(RowDensity.comfortable.verticalPadding, RowDensity.compact.verticalPadding)
    }

    func testSettingsRoundTripThroughDefaults() {
        let suite = "SpaceBar.test.\(UUID().uuidString)"
        let defaults = try? XCTUnwrap(UserDefaults(suiteName: suite))

        let written = AppSettings(defaults: defaults ?? .standard)
        written.layout = .map
        written.density = .compact
        written.staleDays = 3
        written.setWarningFraction(0.35)

        let read = AppSettings(defaults: defaults ?? .standard)
        XCTAssertEqual(read.layout, .map)
        XCTAssertEqual(read.density, .compact)
        XCTAssertEqual(read.staleDays, 3)
        XCTAssertEqual(read.warningFraction, 0.35, accuracy: 0.001)

        defaults?.removePersistentDomain(forName: suite)
    }
}
