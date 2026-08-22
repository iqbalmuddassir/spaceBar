import AppKit
import SwiftUI

struct CleanupPopoverView: View {
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor
    @EnvironmentObject private var store: CleanupStore
    @EnvironmentObject private var reviewCoordinator: ReviewableFilesCoordinator
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var glassNamespace
    @State private var showQuitConfirm = false
    @State private var settingsInitialSection: PanelSettingsView.Section = .appearance

    var body: some View {
        ZStack {
            if let activeStore = reviewCoordinator.activeBrowserStore {
                ReviewableFilesBrowserView(store: activeStore)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else if store.isShowingSettings {
                PanelSettingsView(
                    onBack: { store.isShowingSettings = false },
                    initialSection: settingsInitialSection
                )
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
            if !settings.hasSeenFirstRunPrimer {
                store.showFirstRunPrimer = true
            }
        }
        .animation(LiquidGlassMotion.panel(reduceMotion), value: reviewCoordinator.activeBrowserStore != nil)
        .animation(LiquidGlassMotion.panel(reduceMotion), value: store.isShowingSettings)
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.showFullDiskAccessPrompt)
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.showAutomationAccessPrompt)
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.isBatchConfirming)
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.showFirstRunPrimer)
        .animation(LiquidGlassMotion.panel(reduceMotion), value: store.isScanning)
        .confirmationDialog(
            "Cleanup is still running. Quit anyway?",
            isPresented: $showQuitConfirm,
            titleVisibility: .visible
        ) {
            Button("Quit", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            Button("Keep Cleaning", role: .cancel) { }
        } message: {
            Text("Deletes already started will continue until finished.")
        }
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

            if store.isBatchConfirming {
                BatchCleanConfirmOverlay(
                    targets: selectedResults,
                    totalBytes: selectedBytes,
                    onCancel: { store.isBatchConfirming = false },
                    onConfirm: {
                        store.performBatchClean(
                            selectedResults.map(\.target),
                            diskMonitor: diskMonitor,
                            settings: settings
                        )
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if store.showFullDiskAccessPrompt {
                FullDiskAccessOverlay(isPresented: $store.showFullDiskAccessPrompt)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if store.showAutomationAccessPrompt {
                AutomationAccessOverlay(isPresented: $store.showAutomationAccessPrompt)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if store.showFirstRunPrimer {
                FirstRunPrimerOverlay(
                    isPresented: $store.showFirstRunPrimer,
                    onContinue: {
                        settings.hasSeenFirstRunPrimer = true
                        store.showFirstRunPrimer = false
                    }
                )
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
                    RescanSpinnerIcon(isSpinning: store.isScanning && !reduceMotion)
                }
                .liquidChipButtonStyle()
                .disabled(
                    store.isScanning
                        || store.isDeletingAny
                        || reviewCoordinator.isDeletingAny
                )
                .help("Rescan")
                .accessibilityLabel("Rescan cleanup targets")
                .accessibilityHint("Scans reclaimable caches and review categories again")
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

    /// Fixed so the list reads the same every time, rather than reshuffling section order as
    /// byte totals change between scans.
    private static let categoryOrder: [CleanTargetCategory] = [
        .general, .xcode, .mobile, .packageManagers, .devTools, .aiTools
    ]

    private var groupedCleanupItems: [(category: CleanTargetCategory, results: [TargetScanResult])] {
        let cleanupItems = store.results.filter { !$0.target.isPermanent }
        let byCategory = Dictionary(grouping: cleanupItems, by: \.target.category)
        return Self.categoryOrder.compactMap { category in
            guard let results = byCategory[category], !results.isEmpty else { return nil }
            return (category, results.sorted { $0.byteSize > $1.byteSize })
        }
    }

    @ViewBuilder
    private var content: some View {
        let groups = groupedCleanupItems
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

                    if !reviewStores.isEmpty {
                        sectionLabel("Review First")
                        ForEach(Array(reviewStores.enumerated()), id: \.element.category) { index, reviewStore in
                            ReviewableFilesSummaryRow(store: reviewStore)
                            if index < reviewStores.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }

                    ForEach(groups, id: \.category) { group in
                        sectionLabel(group.category.title)
                        ForEach(Array(group.results.enumerated()), id: \.element.id) { index, result in
                            reclaimRow(for: result)
                            if index < group.results.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }

                    if !groups.isEmpty, !trashItems.isEmpty {
                        Divider().padding(.leading, 16)
                    }
                    ForEach(trashItems) { result in
                        reclaimRow(for: result)
                    }

                    if groups.isEmpty, trashItems.isEmpty, !store.isScanning {
                        emptyCleanupState
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var emptyCleanupState: some View {
        VStack(spacing: 10) {
            if store.excludedTargetsHideAll {
                Text("All cleanup targets are hidden in Settings")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Re-enable targets under Scanning to see reclaimable space again.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                Button("Open Scanning settings") {
                    settingsInitialSection = .scanning
                    store.isShowingSettings = true
                }
                .liquidPillButtonStyle()
            } else {
                Text("No cache cleanup targets right now")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
    }
}

extension CleanupPopoverView {
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
            fallbackCaption: result.recencyCaption(staleAfter: settings.staleInterval) ?? result.target.subtitle,
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
            selectedCount: selectedResults.count,
            selectionSummary: store.selectionSummary(staleAfter: settings.staleInterval),
            statusMessage: store.statusMessage,
            isScanning: store.isScanning,
            isBusy: store.isDeletingAny || store.isScanning,
            targetCount: store.results.count,
            onClean: { store.isBatchConfirming = true },
            onOpenSettings: {
                settingsInitialSection = .appearance
                store.isShowingSettings = true
            },
            onQuit: {
                if store.isDeletingAny || reviewCoordinator.isDeletingAny {
                    showQuitConfirm = true
                } else {
                    NSApplication.shared.terminate(nil)
                }
            }
        )
    }
}

private struct RescanSpinnerIcon: View {
    let isSpinning: Bool

    @State private var angle: Double = 0
    @State private var spinTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .font(.body.weight(.semibold))
            .rotationEffect(.degrees(angle))
            .onChange(of: isSpinning) { _, spinning in
                updateSpinTask(spinning)
            }
            .onAppear { updateSpinTask(isSpinning) }
    }

    private func updateSpinTask(_ spinning: Bool) {
        guard spinning else {
            spinTask?.cancel()
            spinTask = nil
            return
        }
        guard spinTask == nil else { return }
        spinTask = Task { @MainActor in
            while !Task.isCancelled {
                withAnimation(.linear(duration: 1)) {
                    angle += 360
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
