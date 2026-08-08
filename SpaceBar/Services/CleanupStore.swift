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

    private var scanTask: Task<Void, Never>?
    private var hasCompletedInitialScan = false
    private var statusClearTask: Task<Void, Never>?

    func startInitialScan() {
        guard !hasCompletedInitialScan, !isScanning else { return }
        scanAll(clearExisting: true)
    }

    func scanAll(clearExisting: Bool = false) {
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0
        statusMessage = "Scanning…"
        if clearExisting {
            results = []
        } else {
            // Reset row phases so a refresh doesn't keep stale success/error states.
            results = results.map { item in
                var copy = item
                copy.phase = .scanning
                copy.errorMessage = nil
                return copy
            }
        }

        let targets = CleanTargetRegistry.allTargets()
        let total = Double(max(targets.count, 1))

        scanTask = Task {
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
                    if Task.isCancelled { return }
                    completed += 1
                    collected[id] = scanned
                    self.scanProgress = Double(completed) / total
                    let now = Date()
                    if now.timeIntervalSince(lastUIUpdate) > 0.18 || completed == Int(total) {
                        lastUIUpdate = now
                        self.applyCollected(collected, animated: true, preserveBusyPhases: false)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            self.applyCollected(collected, animated: true, preserveBusyPhases: false)
            self.isScanning = false
            self.scanProgress = 1
            self.hasCompletedInitialScan = true
            let reclaim = ByteFormatting.string(from: self.totalReclaimable)
            self.setStatus("Scan complete · \(self.results.count) targets · \(reclaim) reclaimable")
        }
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
        let merged: [TargetScanResult]
        if preserveBusyPhases {
            merged = next.map { item -> TargetScanResult in
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
            merged = next
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

        // Always clean using a fresh registry target so paths are current.
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
            setStatus("Freed \(freed) from \(target.name)")

            try? await Task.sleep(nanoseconds: 450_000_000)
            await rescan(targetID: target.id)
            await diskMonitor.refreshAfterCleaning()
        } catch {
            let cleanerError = (error as? CleanerError) ?? .unknown(error.localizedDescription)
            let hasFDA = await Task.detached { CleanerService.hasFullDiskAccess() }.value
            if cleanerError.isPermissionRelated, !hasFDA {
                showFullDiskAccessPrompt = true
            }
            let message: String
            if cleanerError.isPermissionRelated, hasFDA {
                message = "Some items are locked or in use. Quit related apps and retry."
            } else {
                message = cleanerError.localizedDescription
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

    private func scan(target: CleanTarget) async -> TargetScanResult? {
        await Task.detached(priority: .utility) {
            switch target.strategy {
            case .deletePaths(let urls):
                let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
                guard !existing.isEmpty else {
                    return TargetScanResult(target: target, byteSize: 0, staleDescription: nil, phase: .ready, errorMessage: nil)
                }
                let size = DirectorySizer.size(of: existing)
                let stale = StaleAgeCalculator.staleDescription(for: existing)
                return TargetScanResult(target: target, byteSize: size, staleDescription: stale, phase: .ready, errorMessage: nil)

            case .emptyTrash:
                let info = TrashService.info()
                let stale: String?
                if info.itemCount > 0 {
                    stale = info.itemCount == 1 ? "1 item" : "\(info.itemCount) items"
                } else {
                    stale = nil
                }
                return TargetScanResult(
                    target: target,
                    byteSize: info.byteSize,
                    staleDescription: stale,
                    itemCount: info.itemCount,
                    phase: .ready,
                    errorMessage: nil
                )

            case .simctlDeleteUnavailable:
                let size = Self.estimateSimulatorUnavailableSize()
                return TargetScanResult(target: target, byteSize: size, staleDescription: nil, phase: .ready, errorMessage: nil)

            case .dockerBuilderPrune:
                let size = Self.estimateDockerBuildCacheSize()
                return TargetScanResult(target: target, byteSize: size, staleDescription: nil, phase: .ready, errorMessage: nil)
            }
        }.value
    }

    nonisolated private static func estimateSimulatorUnavailableSize() -> UInt64 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let devices = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        guard FileManager.default.fileExists(atPath: devices.path) else { return 0 }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "unavailable"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").filter { line in
                let s = line.trimmingCharacters(in: .whitespaces)
                return !s.isEmpty && !s.hasPrefix("--") && !s.hasPrefix("==")
            }
            guard !lines.isEmpty else { return 0 }

            var total: UInt64 = 0
            let uuidPattern = #/[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/#
            for line in lines {
                if let match = line.firstMatch(of: uuidPattern) {
                    let uuid = String(match.output)
                    let dir = devices.appendingPathComponent(uuid, isDirectory: true)
                    total += DirectorySizer.size(of: dir)
                }
            }
            return total
        } catch {
            return 0
        }
    }

    nonisolated private static func estimateDockerBuildCacheSize() -> UInt64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "system", "df", "--format", "{{.Type}} {{.Size}}"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return 0 }
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            for line in output.split(separator: "\n") {
                if line.lowercased().contains("build cache") {
                    return parseDockerSize(String(line.split(separator: " ").last ?? "0"))
                }
            }
            return 0
        } catch {
            return 0
        }
    }

    nonisolated private static func parseDockerSize(_ raw: String) -> UInt64 {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let numberPart = String(trimmed.prefix(while: { $0.isNumber || $0 == "." || $0 == "," }))
            .replacingOccurrences(of: ",", with: "")
        guard let value = Double(numberPart) else { return 0 }
        if trimmed.contains("GB") { return UInt64(value * 1_000_000_000) }
        if trimmed.contains("MB") { return UInt64(value * 1_000_000) }
        if trimmed.contains("KB") { return UInt64(value * 1_000) }
        return UInt64(value)
    }
}
