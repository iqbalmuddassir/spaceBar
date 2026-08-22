import Combine
import Foundation
import SwiftUI

struct BatchCleanSummary: Equatable {
    var succeeded: Int
    var failed: Int
    var bytesFreed: UInt64
    var failedNames: [String]

    var statusMessage: String {
        let freed = ByteFormatting.string(from: bytesFreed)
        if failed == 0 {
            let noun = succeeded == 1 ? "target" : "targets"
            return "Cleaned \(succeeded) \(noun) · freed \(freed)"
        }
        if succeeded == 0 {
            let noun = failed == 1 ? "target" : "targets"
            return "Could not clean \(failed) \(noun)"
        }
        return "Freed \(freed) · \(succeeded) ok, \(failed) failed"
    }
}

@MainActor
final class CleanupStore: ObservableObject {
    @Published private(set) var results: [TargetScanResult] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var statusMessage: String?
    @Published var showFullDiskAccessPrompt = false
    @Published var showAutomationAccessPrompt = false
    @Published var isBatchConfirming = false
    @Published var isShowingSettings = false
    @Published var showFirstRunPrimer = false
    @Published private(set) var lastBatchSummary: BatchCleanSummary?
    /// Only rows the user has actually touched. Everything else defers to the recency default,
    /// so a rescan that changes an age also changes what arrives ticked.
    @Published var explicitSelection: [String: Bool] = [:]
    /// Targets the user switched off in Settings. Skipped before the scan, not after, so
    /// unticking one actually makes opening the panel faster.
    var excludedTargetIDs: Set<String> = []

    var totalReclaimable: UInt64 {
        results.reduce(0) { $0 + $1.byteSize }
    }

    var totalReclaimableLabel: String {
        ByteFormatting.string(from: totalReclaimable)
    }

    var isDeletingAny: Bool {
        results.contains { result in
            if case .deleting = result.phase {
                return true
            }
            return false
        }
    }

    private var scanTask: Task<Void, Never>?
    private var hasCompletedInitialScan = false
    private var isPinnedToFixture = false
    private var statusClearTask: Task<Void, Never>?

    func startInitialScan() {
        guard !hasCompletedInitialScan, !isScanning else { return }
        scanAll(clearExisting: true)
    }

    func scanAll(clearExisting: Bool = false) {
        guard !isPinnedToFixture else { return }
        guard !isDeletingAny else {
            setStatus("Wait for the current delete to finish")
            return
        }
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        statusMessage = "Scanning…"
        lastBatchSummary = nil
        prepareResultsForScan(clearExisting: clearExisting)

        let targets = CleanTargetRegistry.allTargets().filter { !excludedTargetIDs.contains($0.id) }
        let total = Double(max(targets.count, 1))

        scanTask = Task {
            await self.runScan(targets: targets, total: total)
        }
    }

    func resetTransientUIState() {
        showFullDiskAccessPrompt = false
        showAutomationAccessPrompt = false
        isBatchConfirming = false
        isShowingSettings = false
        showFirstRunPrimer = false
        lastBatchSummary = nil
    }

    /// Deletes each selected target in turn, keeping the existing per-target guards and
    /// error handling rather than introducing a second delete path.
    func performBatchClean(_ targets: [CleanTarget], diskMonitor: DiskSpaceMonitor, settings: AppSettings) {
        isBatchConfirming = false
        lastBatchSummary = nil
        Task {
            var succeeded = 0
            var failed = 0
            var bytesFreed: UInt64 = 0
            var failedNames: [String] = []

            for target in targets {
                let outcome = await performDelete(target, diskMonitor: diskMonitor, settings: settings)
                switch outcome {
                case let .success(freed):
                    succeeded += 1
                    bytesFreed += freed
                case .failure:
                    failed += 1
                    failedNames.append(target.name)
                }
            }

            let summary = BatchCleanSummary(
                succeeded: succeeded,
                failed: failed,
                bytesFreed: bytesFreed,
                failedNames: failedNames
            )
            lastBatchSummary = summary
            setStatus(summary.statusMessage)

            // Keep failed rows selected for retry; clear overrides so untouched rows can
            // still auto-select later this session when they become cold enough.
            clearSelectionOverrides()
            for name in failedNames {
                if let id = results.first(where: { $0.target.name == name })?.id {
                    explicitSelection[id] = true
                }
            }
        }
    }

    /// Pins the store to the supplied results so no scan — including rescan-on-open — can
    /// replace them with whatever is really on this machine.
    func loadFixture(results: [TargetScanResult], statusMessage: String? = nil) {
        isPinnedToFixture = true
        scanTask?.cancel()
        hasCompletedInitialScan = true
        isScanning = false
        scanProgress = 1
        showFullDiskAccessPrompt = false
        showAutomationAccessPrompt = false
        self.results = results
        self.statusMessage = statusMessage
    }

    private func prepareResultsForScan(clearExisting: Bool) {
        if clearExisting {
            results = []
            return
        }
        results = results.map { item in
            var copy = item
            copy.phase = .scanning
            copy.errorMessage = nil
            return copy
        }
    }

    private func runScan(targets: [CleanTarget], total: Double) async {
        var collected: [String: TargetScanResult] = [:]
        var completed = 0
        var lastUIUpdate = Date.distantPast

        await withTaskGroup(of: (String, TargetScanResult).self) { group in
            for target in targets {
                group.addTask {
                    let scanned = await self.scan(target: target) ?? TargetScanResult(
                        target: target,
                        byteSize: 0,
                        staleDescription: nil,
                        phase: .ready,
                        errorMessage: nil
                    )
                    return (target.id, scanned)
                }
            }

            for await (id, scanned) in group {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                completed += 1
                collected[id] = scanned
                scanProgress = Double(completed) / total
                let now = Date()
                if now.timeIntervalSince(lastUIUpdate) > 0.18 || completed == Int(total) {
                    lastUIUpdate = now
                    applyCollected(collected, animated: true, preserveBusyPhases: false)
                }
            }
        }

        if Task.isCancelled {
            isScanning = false
            return
        }
        applyCollected(collected, animated: true, preserveBusyPhases: false)
        isScanning = false
        scanProgress = 1
        hasCompletedInitialScan = true
        let reclaim = ByteFormatting.string(from: totalReclaimable)
        setStatus("Scan complete · \(results.count) targets · \(reclaim) reclaimable")
    }

    private func applyCollected(
        _ collected: [String: TargetScanResult],
        animated: Bool,
        preserveBusyPhases: Bool
    ) {
        let visible = collected.values.filter(\.isVisible)
        let regular = visible.filter { !$0.target.isPermanent }.sorted { $0.byteSize > $1.byteSize }
        let trash = visible.filter(\.target.isPermanent)
        let next = regular + trash
        let merged: [TargetScanResult] = if preserveBusyPhases {
            next.map { item -> TargetScanResult in
                guard let current = results.first(where: { $0.id == item.id }) else { return item }
                switch current.phase {
                case .deleting, .success:
                    var kept = item
                    kept.phase = current.phase
                    return kept
                default:
                    return item
                }
            }
        } else {
            next
        }
        if animated {
            withAnimation(.snappy(duration: 0.28)) {
                results = merged
            }
        } else {
            results = merged
        }
    }

    func rescan(targetID: String) async {
        let target = CleanTargetRegistry.allTargets().first(where: { $0.id == targetID })
            ?? results.first(where: { $0.id == targetID })?.target
        guard let target else { return }

        let scanned = await scan(target: target)
        withAnimation(.snappy(duration: 0.3)) {
            if var scannedResult = scanned, scannedResult.isVisible {
                if let index = results.firstIndex(where: { $0.id == targetID }) {
                    if scannedResult.errorMessage == nil {
                        scannedResult.errorMessage = results[index].errorMessage
                    }
                    results[index] = scannedResult
                } else {
                    results.append(scannedResult)
                }
                let regular = results.filter { !$0.target.isPermanent }.sorted { $0.byteSize > $1.byteSize }
                let trash = results.filter(\.target.isPermanent)
                results = regular + trash
            } else {
                results.removeAll { $0.id == targetID }
            }
        }
    }
}

extension CleanupStore {
    private func setStatus(_ message: String) {
        statusMessage = message
        statusClearTask?.cancel()
        statusClearTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled {
                statusMessage = nil
            }
        }
    }

    @discardableResult
    func performDelete(
        _ target: CleanTarget,
        diskMonitor: DiskSpaceMonitor,
        settings: AppSettings
    ) async -> Result<UInt64, CleanerError> {
        if let index = results.firstIndex(where: { $0.id == target.id }) {
            withAnimation(.easeInOut(duration: 0.15)) {
                results[index].phase = .deleting
                results[index].errorMessage = nil
            }
        }
        setStatus("Deleting \(target.name)…")

        let liveTarget = CleanTargetRegistry.allTargets().first(where: { $0.id == target.id }) ?? target

        do {
            let cleanResult = try await Task.detached(priority: .userInitiated) {
                try CleanerService.clean(liveTarget)
            }.value

            if let index = results.firstIndex(where: { $0.id == target.id }) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    results[index].phase = .success
                    if cleanResult.bytesFreed > 0 {
                        results[index].byteSize = cleanResult.bytesAfter
                    }
                }
            }
            settings.addReclaimed(cleanResult.bytesFreed)

            let freed = ByteFormatting.string(from: cleanResult.bytesFreed)
            if cleanResult.failedEntries > 0 {
                let failed = cleanResult.failedEntries
                let unit = failed == 1 ? "item" : "items"
                setStatus("Freed \(freed) from \(target.name) · \(failed) \(unit) failed")
                if let index = results.firstIndex(where: { $0.id == target.id }) {
                    if !cleanResult.failedPaths.isEmpty {
                        let uniqueNames = Array(Set(cleanResult.failedPaths)).sorted()
                        let names = uniqueNames.joined(separator: ", ")
                        results[index].errorMessage = "Locked or in use: \(names)"
                    } else {
                        results[index].errorMessage = "\(failed) \(unit) could not be deleted"
                    }
                }
            } else {
                setStatus("Freed \(freed) from \(target.name)")
            }

            try? await Task.sleep(nanoseconds: 450_000_000)
            await rescan(targetID: target.id)
            await diskMonitor.refreshAfterCleaning()
            return .success(cleanResult.bytesFreed)
        } catch {
            return await handleDeleteFailure(error, targetID: target.id)
        }
    }

    private func handleDeleteFailure(
        _ error: Error,
        targetID: String
    ) async -> Result<UInt64, CleanerError> {
        let cleanerError = (error as? CleanerError) ?? .unknown(error.localizedDescription)
        if cleanerError.isAutomationRelated {
            showAutomationAccessPrompt = true
        } else if cleanerError.isPermissionRelated {
            let hasFDA = await Task.detached { CleanerService.hasFullDiskAccess() }.value
            if !hasFDA {
                showFullDiskAccessPrompt = true
            }
        }

        let message = await deleteFailureMessage(for: cleanerError)
        setStatus(message)
        if let index = results.firstIndex(where: { $0.id == targetID }) {
            withAnimation {
                results[index].phase = .error(message)
                results[index].errorMessage = message
            }
        }
        return .failure(cleanerError)
    }

    private func deleteFailureMessage(for cleanerError: CleanerError) async -> String {
        if cleanerError.isAutomationRelated {
            return cleanerError.localizedDescription
        }
        guard cleanerError.isPermissionRelated else {
            return cleanerError.localizedDescription
        }
        let hasFDA = await Task.detached { CleanerService.hasFullDiskAccess() }.value
        return hasFDA
            ? "Some items are locked or in use. Quit related apps and retry."
            : cleanerError.localizedDescription
    }
}
