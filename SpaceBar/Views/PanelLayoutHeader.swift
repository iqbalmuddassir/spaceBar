import SwiftUI

/// Picks the header for the chosen layout. The list, selection and footer beneath are shared,
/// so switching layouts changes only what sits above them.
struct PanelLayoutHeader: View {
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor
    @EnvironmentObject private var store: CleanupStore
    @EnvironmentObject private var reviewCoordinator: ReviewableFilesCoordinator
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        switch settings.layout {
        case .gauge:
            gauge
        case .ledger:
            LedgerHeader(
                monitor: diskMonitor,
                reclaimableBytes: reclaimableBytes,
                itemCount: store.results.count + reviewCoordinator.stores.count
            )
        case .map:
            if MapHeader.isWorthDrawing(mapItems) {
                MapHeader(items: mapItems, onToggle: toggle, onOpenReview: openReview)
            } else {
                // Falling back silently reads as the setting being broken, so say why.
                VStack(alignment: .leading, spacing: 6) {
                    gauge
                    Text(MapHeader.fallbackExplanation)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var gauge: some View {
        GaugeHeader(monitor: diskMonitor, reclaimableBytes: reclaimableBytes)
    }

    private var reclaimableBytes: UInt64 {
        store.totalReclaimable + reviewCoordinator.totalReclaimableBytes
    }

    private var mapItems: [ReclaimMapItem] {
        let reviews = reviewCoordinator.stores
            .filter { $0.totalBytes > 0 }
            .map { reviewStore in
                ReclaimMapItem(
                    id: reviewStore.category.rawValue,
                    name: reviewStore.title,
                    bytes: reviewStore.totalBytes,
                    temperature: nil,
                    isSelected: true,
                    isReview: true
                )
            }
        let caches = store.results.map { result in
            ReclaimMapItem(
                id: result.id,
                name: result.target.name,
                bytes: result.byteSize,
                temperature: result.temperature(staleAfter: settings.staleInterval),
                isSelected: store.isSelected(result, staleAfter: settings.staleInterval),
                isReview: false
            )
        }
        return (reviews + caches).filter { $0.bytes > 0 }
    }

    private func toggle(_ id: String) {
        guard let result = store.results.first(where: { $0.id == id }) else { return }
        store.toggleSelection(result, staleAfter: settings.staleInterval)
    }

    private func openReview(_ id: String) {
        reviewCoordinator.stores.first { $0.category.rawValue == id }?.openBrowser()
    }
}
