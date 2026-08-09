import Foundation

extension CleanupStore {
    func scan(target: CleanTarget) async -> TargetScanResult? {
        await Task.detached(priority: .utility) {
            switch target.strategy {
            case let .deletePaths(urls):
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

            case .emptyTrash:
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

            case .simctlDeleteUnavailable:
                let size = CommandSizeEstimator.simulatorUnavailableSize()
                return TargetScanResult(
                    target: target,
                    byteSize: size,
                    staleDescription: nil,
                    phase: .ready,
                    errorMessage: nil
                )

            case .dockerBuilderPrune:
                let size = CommandSizeEstimator.dockerBuildCacheSize()
                return TargetScanResult(
                    target: target,
                    byteSize: size,
                    staleDescription: nil,
                    phase: .ready,
                    errorMessage: nil
                )
            }
        }.value
    }
}
