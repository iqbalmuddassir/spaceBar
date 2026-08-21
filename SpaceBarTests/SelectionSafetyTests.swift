import XCTest
@testable import SpaceBar

@MainActor
final class SelectionSafetyTests: XCTestCase {
    private let staleAfter: TimeInterval = 30 * RelativeAge.day
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testNilRecencyIsNotSafeByDefault() {
        let result = makeResult(id: "docker", name: "Docker", recency: nil, requiresStrongConfirm: false)
        XCTAssertFalse(result.isSafeByDefault(staleAfter: staleAfter, now: now))
        XCTAssertTrue(result.hasUnknownAge)
        XCTAssertEqual(
            result.recencyCaption(staleAfter: staleAfter, now: now),
            "Age unknown — review before cleaning"
        )
    }

    func testColdRecencyIsSafeByDefault() {
        let touched = now.addingTimeInterval(-60 * RelativeAge.day)
        let result = makeResult(
            id: "derived",
            name: "DerivedData",
            recency: Recency(activity: .built, lastTouched: touched),
            requiresStrongConfirm: false
        )
        XCTAssertTrue(result.isSafeByDefault(staleAfter: staleAfter, now: now))
    }

    func testStrongConfirmNeverSafeByDefaultEvenWhenCold() {
        let touched = now.addingTimeInterval(-60 * RelativeAge.day)
        let result = makeResult(
            id: "archives",
            name: "Archives",
            recency: Recency(activity: .used, lastTouched: touched),
            requiresStrongConfirm: true
        )
        XCTAssertFalse(result.isSafeByDefault(staleAfter: staleAfter, now: now))
    }

    func testCLIStyleResultsAreNotAutoSelected() {
        let store = CleanupStore()
        let docker = makeResult(id: "docker-builder-prune", name: "Docker", recency: nil)
        let simctl = makeResult(id: "simctl-unavailable", name: "Simulators", recency: nil)
        store.loadFixture(results: [docker, simctl])

        XCTAssertFalse(store.isSelected(docker, staleAfter: staleAfter, now: now))
        XCTAssertFalse(store.isSelected(simctl, staleAfter: staleAfter, now: now))
        XCTAssertEqual(store.heldBackCount(staleAfter: staleAfter, now: now), 2)
    }

    func testOutsideClickGuardIncludesBatchConfirmAndDeleting() {
        XCTAssertTrue(
            StatusItemController.shouldBlockOutsideDismiss(
                isBatchConfirming: true,
                showFullDiskAccessPrompt: false,
                isConfirmingAnyDelete: false
            )
        )
        XCTAssertTrue(
            StatusItemController.shouldBlockOutsideDismiss(
                isBatchConfirming: false,
                showFullDiskAccessPrompt: false,
                showAutomationAccessPrompt: true,
                isConfirmingAnyDelete: false
            )
        )
        XCTAssertTrue(
            StatusItemController.shouldBlockOutsideDismiss(
                isBatchConfirming: false,
                showFullDiskAccessPrompt: false,
                isConfirmingAnyDelete: false,
                isDeletingAny: true
            )
        )
        XCTAssertFalse(
            StatusItemController.shouldBlockOutsideDismiss(
                isBatchConfirming: false,
                showFullDiskAccessPrompt: false,
                isConfirmingAnyDelete: false,
                isDeletingAny: false
            )
        )
    }

    func testSafeCacheChildrenSkipsDedicatedAIFolders() throws {
        let caches = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpaceBarCacheSkip-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: caches) }
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)

        for name in ["ollama", "claude-cli-nodejs", "SomeApp"] {
            try FileManager.default.createDirectory(
                at: caches.appendingPathComponent(name, isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        let children = CleanTargetRegistry.safeCacheChildren(of: caches)
        let names = Set(children.map(\.lastPathComponent))
        XCTAssertFalse(names.contains("ollama"))
        XCTAssertFalse(names.contains("claude-cli-nodejs"))
        XCTAssertTrue(names.contains("SomeApp"))
        XCTAssertTrue(CleanTargetRegistry.skippedCacheNames.contains("ollama"))
        XCTAssertTrue(CleanTargetRegistry.skippedCacheNames.contains("claude-cli-nodejs"))
        let dedicated = CleanTargetRegistry.dedicatedLibraryCachesFolderNames()
        XCTAssertTrue(dedicated.isSubset(of: CleanTargetRegistry.skippedCacheNames))
        for name in dedicated {
            XCTAssertFalse(names.contains(name), "\(name) should be skipped from App Caches children")
        }
    }

    func testTrashWithZeroBytesStillEntersSelectedResults() {
        let store = CleanupStore()
        let trashTarget = CleanTarget(
            id: "trash",
            name: "Empty Trash",
            subtitle: "Trash",
            safetyNote: "Permanent",
            strategy: .emptyTrash,
            requiresStrongConfirm: true,
            isPermanent: true
        )
        let trash = TargetScanResult(
            target: trashTarget,
            byteSize: 0,
            itemCount: 3,
            phase: .ready
        )
        store.loadFixture(results: [trash])
        store.explicitSelection[trash.id] = true

        let selected = store.selectedResults(staleAfter: staleAfter, now: now)
        XCTAssertEqual(selected.count, 1)
        XCTAssertEqual(selected.first?.id, "trash")
        XCTAssertEqual(selected.first?.sizeLabel, "size unknown")
    }

    func testSelectAllNeverSelectsTrash() {
        let store = CleanupStore()
        let cache = makeResult(id: "cache", name: "Caches", recency: nil)
        let trashTarget = CleanTarget(
            id: "trash",
            name: "Empty Trash",
            subtitle: "Trash",
            safetyNote: "Permanent",
            strategy: .emptyTrash,
            requiresStrongConfirm: true,
            isPermanent: true
        )
        let trash = TargetScanResult(target: trashTarget, byteSize: 100, itemCount: 2, phase: .ready)
        store.loadFixture(results: [cache, trash])
        store.setAllSelected(true)

        XCTAssertEqual(store.explicitSelection["trash"], false)
        XCTAssertEqual(store.explicitSelection["cache"], true)
    }

    private func makeResult(
        id: String,
        name: String,
        recency: Recency?,
        requiresStrongConfirm: Bool = false
    ) -> TargetScanResult {
        TargetScanResult(
            target: CleanTarget(
                id: id,
                name: name,
                subtitle: name,
                safetyNote: "test",
                strategy: .deletePaths([]),
                requiresStrongConfirm: requiresStrongConfirm,
                isPermanent: false
            ),
            byteSize: 1000,
            phase: .ready,
            recency: recency
        )
    }
}
