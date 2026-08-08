import Combine
import Foundation
import SwiftUI

@MainActor
final class CleanupStore: ObservableObject {
    @Published private(set) var results: [TargetScanResult] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanProgress: Double = 0
    @Published private(set) var statusMessage: String?
    @Published var showFullDiskAccessPrompt = false
    @Published var pendingConfirmID: String?

    var pendingConfirm: CleanTarget? {
        guard let pendingConfirmID else { return nil }
        return results.first(where: { $0.id == pendingConfirmID })?.target
            ?? CleanTargetRegistry.allTargets().first(where: { $0.id == pendingConfirmID })
    }

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
    private var statusClearTask: Task<Void, Never>?

    func startInitialScan() {
        guard !hasCompletedInitialScan, !isScanning else { return }
        scanAll(clearExisting: true)
    }

    func scanAll(clearExisting: Bool = false) {
        guard !isDeletingAny else {
            setStatus("Wait for the current delete to finish")
            return
        }
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        statusMessage = "Scanning…"
        prepareResultsForScan(clearExisting: clearExisting)

        let targets = CleanTargetRegistry.allTargets()
        let total = Double(max(targets.count, 1))

        scanTask = Task {
            await self.runScan(targets: targets, total: total)
        }
    }

    func resetTransientUIState() {
        pendingConfirmID = nil
        showFullDiskAccessPrompt = false
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
            if let scanned, scanned.isVisible {
                if let index = results.firstIndex(where: { $0.id == targetID }) {
                    results[index] = scanned
                } else {
                    results.append(scanned)
                }
                let regular = results.filter { !$0.target.isPermanent }.sorted { $0.byteSize > $1.byteSize }
                let trash = results.filter(\.target.isPermanent)
                results = regular + trash
            } else {
                results.removeAll { $0.id == targetID }
            }
        }
    }

    func requestDelete(_ target: CleanTarget) {
        withAnimation(.snappy(duration: 0.2)) {
            pendingConfirmID = target.id
        }
    }

    func cancelConfirm() {
        withAnimation(.snappy(duration: 0.2)) {
            pendingConfirmID = nil
        }
    }

    func confirmDelete(_ target: CleanTarget, diskMonitor: DiskSpaceMonitor) {
        withAnimation(.snappy(duration: 0.2)) {
            pendingConfirmID = nil
        }
        Task {
            await performDelete(target, diskMonitor: diskMonitor)
        }
    }

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

    private func performDelete(_ target: CleanTarget, diskMonitor: DiskSpaceMonitor) async {
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

            let freed = ByteFormatting.string(from: cleanResult.bytesFreed)
            if cleanResult.failedEntries > 0 {
                let failed = cleanResult.failedEntries
                let unit = failed == 1 ? "item" : "items"
                setStatus("Freed \(freed) from \(target.name) · \(failed) \(unit) failed")
                if let index = results.firstIndex(where: { $0.id == target.id }) {
                    results[index].errorMessage = "\(failed) \(unit) could not be deleted"
                }
            } else {
                setStatus("Freed \(freed) from \(target.name)")
            }

            try? await Task.sleep(nanoseconds: 450_000_000)
            await rescan(targetID: target.id)
            await diskMonitor.refreshAfterCleaning()
        } catch {
            let cleanerError = (error as? CleanerError) ?? .unknown(error.localizedDescription)
            let hasFDA = await Task.detached { CleanerService.hasFullDiskAccess() }.value
            if cleanerError.isPermissionRelated, !hasFDA {
                showFullDiskAccessPrompt = true
            }
            let message: String = if cleanerError.isPermissionRelated, hasFDA {
                "Some items are locked or in use. Quit related apps and retry."
            } else {
                cleanerError.localizedDescription
            }
            setStatus(message)
            if let index = results.firstIndex(where: { $0.id == target.id }) {
                withAnimation {
                    results[index].phase = .error(message)
                    results[index].errorMessage = message
                }
            }
        }
    }
}
