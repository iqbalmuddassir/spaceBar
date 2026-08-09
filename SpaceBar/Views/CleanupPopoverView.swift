import AppKit
import SwiftUI

struct CleanupPopoverView: View {
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor
    @EnvironmentObject private var store: CleanupStore
    @EnvironmentObject private var reviewCoordinator: ReviewableFilesCoordinator
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
            store.startInitialScan()
        }
        .animation(LiquidGlassMotion.panel(reduceMotion), value: reviewCoordinator.activeBrowserStore != nil)
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

            if store.showFullDiskAccessPrompt {
                FullDiskAccessOverlay(isPresented: $store.showFullDiskAccessPrompt)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
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

            DiskSpaceStatusCard(monitor: diskMonitor)

            reclaimChip
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var reclaimChip: some View {
        let cacheReclaim = store.totalReclaimable
        let filesReclaim = reviewCoordinator.totalReclaimableBytes
        let combined = cacheReclaim + filesReclaim
        if combined > 0 {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.secondary)
                Text("Can reclaim \(ByteFormatting.string(from: combined))")
                    .font(.caption.weight(.semibold))
                    .contentTransition(.numericText())
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    if cacheReclaim > 0 {
                        Text("Caches \(store.totalReclaimableLabel)")
                    }
                    if filesReclaim > 0 {
                        Text("Files \(reviewCoordinator.totalReclaimableLabel)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidGlass(in: Capsule())
            .liquidGlassTransitionMaterialize()
        }
    }

    @ViewBuilder
    private var content: some View {
        let cleanupItems = store.results.filter { !$0.target.isPermanent }
        let trashItems = store.results.filter(\.target.isPermanent)
        let reviewStores = reviewCoordinator.stores

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
                    sectionLabel("Files")
                    ForEach(Array(reviewStores.enumerated()), id: \.element.category) { index, reviewStore in
                        ReviewableFilesSummaryRow(store: reviewStore)
                        if index < reviewStores.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }

                    if !cleanupItems.isEmpty {
                        sectionLabel("Cleanup")
                        ForEach(Array(cleanupItems.enumerated()), id: \.element.id) { index, result in
                            CleanupRowView(
                                result: result,
                                isConfirming: store.pendingConfirmID == result.id
                            ) {
                                store.requestDelete(result.target)
                            }
                            if index < cleanupItems.count - 1 {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }

                    if !trashItems.isEmpty {
                        sectionLabel("Trash")
                        ForEach(trashItems) { result in
                            CleanupRowView(
                                result: result,
                                isConfirming: store.pendingConfirmID == result.id
                            ) {
                                store.requestDelete(result.target)
                            }
                        }
                    }

                    if cleanupItems.isEmpty, trashItems.isEmpty, !store.isScanning {
                        VStack(spacing: 6) {
                            Text("No cache cleanup targets right now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }
                .padding(.vertical, 4)
            }
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
        HStack {
            Group {
                if let status = store.statusMessage {
                    Text(status)
                        .lineLimit(2)
                } else if store.isScanning {
                    Text("Updating sizes…")
                } else {
                    Text("\(store.results.count) targets")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .liquidChipButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Divider().opacity(0.55)
        }
    }
}
