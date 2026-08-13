import AppKit
import SwiftUI

struct CleanupPopoverView: View {
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor
    @EnvironmentObject private var store: CleanupStore
    @EnvironmentObject private var reviewCoordinator: ReviewableFilesCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var glassNamespace

    var body: some View {
        ZStack {
            if let activeStore = reviewCoordinator.activeBrowserStore {
                ReviewableFilesBrowserView(store: activeStore)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else if store.isShowingSettings {
                PanelSettingsView { store.isShowingSettings = false }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                mainContent
                    .background {
                        PanelGlassBackground(cornerRadius: 18)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.liquidGlassNamespace, glassNamespace)
        .onAppear {
            if settings.rescanOnOpen {
                store.scanAll()
                reviewCoordinator.scanAll()
                diskMonitor.refresh()
            } else {
                store.startInitialScan()
            }
        }
        .animation(LiquidGlassMotion.panel(reduceMotion), value: reviewCoordinator.activeBrowserStore != nil)
        .animation(LiquidGlassMotion.panel(reduceMotion), value: store.isShowingSettings)
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.pendingConfirmID)
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.showFullDiskAccessPrompt)
        .animation(LiquidGlassMotion.panel(reduceMotion), value: store.isScanning)
    }

    private var mainContent: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                if store.isScanning {
                    ProgressView(value: store.scanProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 6)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                content
                footer
            }

            if let pending = store.pendingConfirm {
                CleanupConfirmOverlay(
                    target: pending,
                    onCancel: { store.cancelConfirm() },
                    onConfirm: { store.confirmDelete(pending, diskMonitor: diskMonitor) }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if store.isBatchConfirming {
                BatchCleanConfirmOverlay(
                    targets: selectedResults,
                    totalBytes: selectedBytes,
                    onCancel: { store.isBatchConfirming = false },
                    onConfirm: {
                        store.performBatchClean(
                            selectedResults.map(\.target),
                            diskMonitor: diskMonitor
                        )
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if store.showFullDiskAccessPrompt {
                FullDiskAccessOverlay(isPresented: $store.showFullDiskAccessPrompt)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var selectedResults: [TargetScanResult] {
        store.selectedResults(staleAfter: settings.staleInterval)
    }

    private var selectedBytes: UInt64 {
        store.selectedBytes(staleAfter: settings.staleInterval)
    }

    private var reclaimableBytes: UInt64 {
        store.totalReclaimable + reviewCoordinator.totalReclaimableBytes
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    Text("SpaceBar")
                        .font(.headline)
                }
                Spacer()
                Button {
                    store.scanAll(clearExisting: true)
                    reviewCoordinator.scanAll()
                    diskMonitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.body.weight(.semibold))
                        .rotationEffect(.degrees(store.isScanning ? 360 : 0))
                        .animation(
                            store.isScanning
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: store.isScanning
                        )
                }
                .liquidChipButtonStyle()
                .disabled(
                    store.isScanning
                        || store.isDeletingAny
                        || reviewCoordinator.isDeletingAny
                        || store.pendingConfirmID != nil
                )
                .help("Rescan")
            }

            layoutHeader
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, settings.layout == .ledger ? 6 : 12)
    }

    private var layoutHeader: some View {
        PanelLayoutHeader()
    }

    @ViewBuilder
    private var content: some View {
        let cleanupItems = store.results.filter { !$0.target.isPermanent }
        let trashItems = store.results.filter(\.target.isPermanent)
        let reviewStores = reviewCoordinator.activeStores

        if store.isScanning, store.results.isEmpty, reviewCoordinator.totalReclaimableBytes == 0 {
            VStack(spacing: 12) {
                ProgressView()
                Text("Scanning…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    listHeader

                    ForEach(Array(reviewStores.enumerated()), id: \.element.category) { index, reviewStore in
                        ReviewableFilesSummaryRow(store: reviewStore)
                        if index < reviewStores.count - 1 || !cleanupItems.isEmpty || !trashItems.isEmpty {
                            Divider().padding(.leading, 16)
                        }
                    }

                    ForEach(Array(cleanupItems.enumerated()), id: \.element.id) { index, result in
                        reclaimRow(for: result)
                        if index < cleanupItems.count - 1 || !trashItems.isEmpty {
                            Divider().padding(.leading, 16)
                        }
                    }

                    ForEach(trashItems) { result in
                        reclaimRow(for: result)
                    }

                    if cleanupItems.isEmpty, trashItems.isEmpty, !store.isScanning {
                        Text("No cache cleanup targets right now")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var listHeader: some View {
        ReclaimListHeader(allSelected: allSelected) {
            store.setAllSelected(!allSelected)
        }
    }

    private var allSelected: Bool {
        let selectable = store.results.filter { !$0.target.isPermanent }
        guard !selectable.isEmpty else { return false }
        return selectable.allSatisfy { store.isSelected($0, staleAfter: settings.staleInterval) }
    }

    private func reclaimRow(for result: TargetScanResult) -> some View {
        ReclaimRowView(
            title: result.target.name,
            sizeLabel: result.sizeLabel,
            recency: result.recency,
            fallbackCaption: result.staleDescription ?? result.target.subtitle,
            kindBadge: result.target.isPermanent ? "trash" : "cache",
            isSelected: store.isSelected(result, staleAfter: settings.staleInterval),
            phase: result.phase,
            errorMessage: result.errorMessage,
            staleAfter: settings.staleInterval,
            density: settings.density
        ) {
            store.toggleSelection(result, staleAfter: settings.staleInterval)
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .tracking(0.4)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private var footer: some View {
        PanelFooter(
            selectedBytes: selectedBytes,
            selectionSummary: store.selectionSummary(staleAfter: settings.staleInterval),
            statusMessage: store.statusMessage,
            isScanning: store.isScanning,
            isBusy: store.isDeletingAny || store.isScanning,
            targetCount: store.results.count,
            onClean: { store.isBatchConfirming = true },
            onOpenSettings: { store.isShowingSettings = true }
        )
    }
}
