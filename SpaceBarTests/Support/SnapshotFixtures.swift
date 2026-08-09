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
            case .low: 128_000_000_000 // 25% free → warning
            case .critical: 25_600_000_000 // 5% free → critical
            }
        }

        var snapshotName: String {
            rawValue
        }
    }

    @MainActor
    static func diskMonitor(for freeSpaceCase: FreeSpaceCase) -> DiskSpaceMonitor {
        diskMonitor(freeBytes: freeSpaceCase.freeBytes, totalBytes: totalBytes)
    }

    @MainActor
    static func diskMonitor(
        freeBytes: UInt64,
        totalBytes: UInt64 = totalBytes
    ) -> DiskSpaceMonitor {
        let monitor = DiskSpaceMonitor()
        monitor.applyFixture(freeBytes: freeBytes, totalBytes: totalBytes)
        return monitor
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
        }
    }

    private static func sampleCleanupResults() -> [TargetScanResult] {
        [
            readyResult(
                id: "xcode-derived",
                name: "Xcode DerivedData",
                subtitle: "~/Library/Developer/Xcode/DerivedData",
                note: "Xcode will rebuild DerivedData on the next build.",
                bytes: 14_200_000_000,
                stale: "last modified 12 days ago"
            ),
            readyResult(
                id: "gradle-caches",
                name: "Gradle Caches",
                subtitle: "~/.gradle/caches",
                note: "Next Gradle build will re-download dependencies.",
                bytes: 3_400_000_000,
                stale: "last modified 3 days ago"
            ),
            readyResult(
                id: "npm",
                name: "npm Cache",
                subtitle: "~/.npm/_cacache",
                note: "npm will rebuild its package cache on demand.",
                bytes: 890_000_000,
                stale: "last modified 5 hours ago"
            ),
            readyResult(
                id: "empty-trash",
                name: "Empty Trash",
                subtitle: "Finder Trash",
                note: "Permanently deletes all items currently in Trash.",
                bytes: 420_000_000,
                stale: "12 items",
                strategy: .emptyTrash,
                strongConfirm: true,
                permanent: true,
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

    private static func readyResult(
        id: String,
        name: String,
        subtitle: String,
        note: String,
        bytes: UInt64,
        stale: String,
        strategy: CleanStrategy = .deletePaths([]),
        strongConfirm: Bool = false,
        permanent: Bool = false,
        itemCount: Int? = nil
    ) -> TargetScanResult {
        TargetScanResult(
            target: CleanTarget(
                id: id,
                name: name,
                subtitle: subtitle,
                safetyNote: note,
                strategy: strategy,
                requiresStrongConfirm: strongConfirm,
                isPermanent: permanent
            ),
            byteSize: bytes,
            staleDescription: stale,
            itemCount: itemCount,
            phase: .ready,
            errorMessage: nil
        )
    }
}
