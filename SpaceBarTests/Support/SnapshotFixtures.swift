import Foundation
@testable import SpaceBar

enum SnapshotFixtures {
    static let panelSize = CGSize(width: 420, height: 560)
    static let totalBytes: UInt64 = 512_000_000_000

    enum FreeSpaceCase: String, CaseIterable {
        case good
        case low
        case critical

        var freeBytes: UInt64 {
            switch self {
            case .good: 320_000_000_000 // ~62.5% free → healthy
            case .low: 76_800_000_000 // 15% free → warning (defaults: warn 20%, critical 10%)
            case .critical: 25_600_000_000 // 5% free → critical
            }
        }

        var snapshotName: String {
            rawValue
        }
    }

    @MainActor
    static func diskMonitor(
        for freeSpaceCase: FreeSpaceCase,
        settings: AppSettings? = nil
    ) -> DiskSpaceMonitor {
        diskMonitor(freeBytes: freeSpaceCase.freeBytes, totalBytes: totalBytes, settings: settings)
    }

    @MainActor
    static func diskMonitor(
        freeBytes: UInt64,
        totalBytes: UInt64 = totalBytes,
        settings: AppSettings? = nil
    ) -> DiskSpaceMonitor {
        let monitor = DiskSpaceMonitor(settings: settings ?? .ephemeral())
        monitor.applyFixture(freeBytes: freeBytes, totalBytes: totalBytes)
        return monitor
    }

    /// Snapshots pin to shipping defaults so a stored preference can never change a reference image.
    @MainActor
    static func settings() -> AppSettings {
        let settings = AppSettings.ephemeral()
        // Primer would cover the panel and invalidate every cleanup snapshot.
        settings.hasSeenFirstRunPrimer = true
        return settings
    }

    @MainActor
    static func cleanupStore() -> CleanupStore {
        let store = CleanupStore()
        store.loadFixture(
            results: sampleCleanupResults(),
            statusMessage: "Scan complete · 4 targets · 18.91 GB reclaimable"
        )
        return store
    }

    @MainActor
    static func reviewCoordinator() -> ReviewableFilesCoordinator {
        let coordinator = ReviewableFilesCoordinator()
        for store in coordinator.stores {
            store.loadFixture(files: sampleFiles(for: store.category))
        }
        return coordinator
    }

    @MainActor
    static func reviewStore(for category: ReviewableFileCategory) -> ReviewableFilesStore {
        let store = ReviewableFilesStore(category: category)
        store.loadFixture(files: sampleFiles(for: category))
        return store
    }

    static func sampleFiles(for category: ReviewableFileCategory) -> [ReviewableFile] {
        switch category {
        case .screenshotsAndRecordings: sampleCaptureFiles()
        case .installerPackages: sampleInstallerFiles()
        case .projectBuildFiles: sampleBuildArtifacts()
        }
    }

    private static func sampleCleanupResults() -> [TargetScanResult] {
        [
            readyResult(
                target: cacheTarget(
                    id: "xcode-derived",
                    name: "Xcode DerivedData",
                    subtitle: "~/Library/Developer/Xcode/DerivedData",
                    note: "Xcode will rebuild DerivedData on the next build.",
                    activity: .built
                ),
                bytes: 14_200_000_000,
                daysAgo: 45
            ),
            readyResult(
                target: cacheTarget(
                    id: "gradle-caches",
                    name: "Gradle Caches",
                    subtitle: "~/.gradle/caches",
                    note: "Next Gradle build will re-download dependencies.",
                    activity: .built
                ),
                bytes: 3_400_000_000,
                daysAgo: 40
            ),
            readyResult(
                target: cacheTarget(
                    id: "npm",
                    name: "npm Cache",
                    subtitle: "~/.npm/_cacache",
                    note: "npm will rebuild its package cache on demand.",
                    activity: .downloaded
                ),
                bytes: 890_000_000,
                daysAgo: 5.0 / 24.0
            ),
            readyResult(
                target: trashTarget(),
                bytes: 420_000_000,
                daysAgo: 20,
                stale: "12 items",
                itemCount: 12
            )
        ]
    }

    private static func sampleCaptureFiles() -> [ReviewableFile] {
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
        let modified = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        return [
            ReviewableFile(
                id: desktop.appendingPathComponent("Screenshot 2026-07-01 at 10.00.00.png"),
                url: desktop.appendingPathComponent("Screenshot 2026-07-01 at 10.00.00.png"),
                kind: .screenshot,
                byteSize: 2_400_000,
                modified: modified
            ),
            ReviewableFile(
                id: desktop.appendingPathComponent("Screenshot 2026-07-01 at 11.00.00.png"),
                url: desktop.appendingPathComponent("Screenshot 2026-07-01 at 11.00.00.png"),
                kind: .screenshot,
                byteSize: 1_800_000,
                modified: modified
            ),
            ReviewableFile(
                id: desktop.appendingPathComponent("Screen Recording 2026-07-01 at 12.00.00.mov"),
                url: desktop.appendingPathComponent("Screen Recording 2026-07-01 at 12.00.00.mov"),
                kind: .recording,
                byteSize: 185_000_000,
                modified: modified
            )
        ]
    }

    private static func sampleInstallerFiles() -> [ReviewableFile] {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        let modified = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        return [
            ReviewableFile(
                id: downloads.appendingPathComponent("Xcode_16.dmg"),
                url: downloads.appendingPathComponent("Xcode_16.dmg"),
                kind: .installer,
                byteSize: 3_100_000_000,
                modified: modified
            ),
            ReviewableFile(
                id: downloads.appendingPathComponent("Docker.pkg"),
                url: downloads.appendingPathComponent("Docker.pkg"),
                kind: .installer,
                byteSize: 620_000_000,
                modified: modified
            )
        ]
    }

    private static func sampleBuildArtifacts() -> [ReviewableFile] {
        let projects = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Projects", isDirectory: true)
        let modified = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 20))!
        return [
            buildArtifact(
                projects.appendingPathComponent("storefront/node_modules"),
                project: "storefront",
                label: "Node dependencies",
                note: "npm install (or yarn/pnpm install) puts it back.",
                bytes: 1_240_000_000,
                modified: modified
            ),
            buildArtifact(
                projects.appendingPathComponent("ledger-cli/target"),
                project: "ledger-cli",
                label: "Rust build output",
                note: "cargo build regenerates it.",
                bytes: 840_000_000,
                modified: modified
            ),
            buildArtifact(
                projects.appendingPathComponent("PhotoKit/Pods"),
                project: "PhotoKit",
                label: "CocoaPods dependencies",
                note: "pod install puts them back.",
                bytes: 310_000_000,
                modified: modified
            ),
            buildArtifact(
                projects.appendingPathComponent("forecast/.venv"),
                project: "forecast",
                label: "Python virtualenv",
                note: "Recreate with python -m venv and pip install -r requirements.",
                bytes: 96_000_000,
                modified: modified
            )
        ]
    }

    private static func buildArtifact(
        _ url: URL,
        project: String,
        label: String,
        note: String,
        bytes: UInt64,
        modified: Date
    ) -> ReviewableFile {
        ReviewableFile(
            id: url,
            url: url,
            kind: .buildArtifact,
            byteSize: bytes,
            modified: modified,
            projectName: project,
            detailLabel: label,
            regenerationNote: note
        )
    }

    /// Ages are offsets from "now" rather than absolute dates, so the rendered phrase
    /// ("45 days ago") stays identical however long after recording the suite runs.
    private static func readyResult(
        target: CleanTarget,
        bytes: UInt64,
        daysAgo: Double,
        stale: String? = nil,
        itemCount: Int? = nil
    ) -> TargetScanResult {
        TargetScanResult(
            target: target,
            byteSize: bytes,
            staleDescription: stale,
            itemCount: itemCount,
            phase: .ready,
            errorMessage: nil,
            recency: Recency(
                activity: target.activity,
                lastTouched: Date().addingTimeInterval(-daysAgo * RelativeAge.day)
            )
        )
    }

    private static func cacheTarget(
        id: String,
        name: String,
        subtitle: String,
        note: String,
        activity: CleanupActivity
    ) -> CleanTarget {
        CleanTarget(
            id: id,
            name: name,
            subtitle: subtitle,
            safetyNote: note,
            strategy: .deletePaths([]),
            requiresStrongConfirm: false,
            isPermanent: false,
            activity: activity
        )
    }

    private static func trashTarget() -> CleanTarget {
        CleanTarget(
            id: "empty-trash",
            name: "Empty Trash",
            subtitle: "Finder Trash",
            safetyNote: "Permanently deletes all items currently in Trash.",
            strategy: .emptyTrash,
            requiresStrongConfirm: true,
            isPermanent: true,
            activity: .trashed
        )
    }
}
