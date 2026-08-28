import Foundation

extension CleanupStore {
    func scan(target: CleanTarget) async -> TargetScanResult? {
        await Task.detached(priority: .utility) {
            switch target.strategy {
            case let .deletePaths(urls):
                Self.scanDeletePaths(urls, target: target)
            case .emptyTrash:
                Self.scanEmptyTrash(target: target)
            case .simctlDeleteUnavailable:
                Self.commandSizeResult(CommandSizeEstimator.simulatorUnavailableSize(), target: target)
            case .dockerBuilderPrune:
                Self.commandSizeResult(CommandSizeEstimator.dockerBuildCacheSize(), target: target)
            case .dockerSystemPrune:
                Self.commandSizeResult(CommandSizeEstimator.dockerReclaimableSize(), target: target)
            case .simctlDeleteUnusedRuntimes:
                Self.commandSizeResult(CommandSizeEstimator.simulatorUnusedRuntimeSize(), target: target)
            case .timeMachineThinLocalSnapshots:
                Self.commandSizeResult(CommandSizeEstimator.timeMachineLocalSnapshotSize(), target: target)
            }
        }.value
    }

    private nonisolated static func scanDeletePaths(_ urls: [URL], target: CleanTarget) -> TargetScanResult {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else {
            return TargetScanResult(
                target: target,
                byteSize: 0,
                staleDescription: nil,
                phase: .ready,
                errorMessage: nil
            )
        }
        let size = DirectorySizer.size(of: existing)
        let touched = StaleAgeCalculator.newestModificationDate(for: existing)
        return TargetScanResult(
            target: target,
            byteSize: size,
            staleDescription: nil,
            phase: .ready,
            errorMessage: nil,
            recency: touched.map { Recency(activity: target.activity, lastTouched: $0) }
        )
    }

    private nonisolated static func scanEmptyTrash(target: CleanTarget) -> TargetScanResult {
        let info = TrashService.info()
        let stale: String? = if info.itemCount > 0 {
            info.itemCount == 1 ? "1 item" : "\(info.itemCount) items"
        } else {
            nil
        }
        return TargetScanResult(
            target: target,
            byteSize: info.byteSize,
            staleDescription: stale,
            itemCount: info.itemCount,
            phase: .ready,
            errorMessage: nil,
            recency: info.newestDate.map { Recency(activity: target.activity, lastTouched: $0) }
        )
    }

    private nonisolated static func commandSizeResult(_ size: UInt64, target: CleanTarget) -> TargetScanResult {
        TargetScanResult(target: target, byteSize: size, staleDescription: nil, phase: .ready, errorMessage: nil)
    }
}
