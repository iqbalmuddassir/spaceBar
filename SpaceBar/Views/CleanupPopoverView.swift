import AppKit
import SwiftUI

struct CleanupPopoverView: View {
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor
    @EnvironmentObject private var store: CleanupStore
    @EnvironmentObject private var mediaStore: MediaCaptureStore

    var body: some View {
        ZStack {
            if mediaStore.showBrowser {
                MediaCaptureBrowserView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                mainContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            store.startInitialScan()
        }
        .animation(.snappy(duration: 0.22), value: mediaStore.showBrowser)
        .animation(.snappy(duration: 0.22), value: store.pendingConfirmID)
        .animation(.snappy(duration: 0.22), value: store.showFullDiskAccessPrompt)
        .animation(.snappy(duration: 0.22), value: store.isScanning)
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
                        .transition(.opacity)
                }
                Divider()
                content
                Divider()
                footer
            }

            if let pending = store.pendingConfirm {
                confirmOverlay(pending)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }

            if store.showFullDiskAccessPrompt {
                fullDiskAccessOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private var fullDiskAccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { store.showFullDiskAccessPrompt = false }

            VStack(alignment: .leading, spacing: 12) {
                Text("Full Disk Access Needed")
                    .font(.headline)
                Text("macOS blocked this cleanup. Enable Full Disk Access for SpaceBar:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Open Privacy & Security → Full Disk Access", systemImage: "1.circle.fill")
                    Label("Enable SpaceBar (add it with + if missing)", systemImage: "2.circle.fill")
                    Label("Quit SpaceBar, reopen, then Clean again", systemImage: "3.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(
                    """
                    If SpaceBar is already enabled, turn it off and on again, then quit and reopen this app. \
                    Ad-hoc debug builds need a fresh grant after rebuilds.
                    """
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

                Text("Running: \(Bundle.main.bundlePath)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.quaternary)
                    .lineLimit(2)
                    .textSelection(.enabled)

                HStack(spacing: 10) {
                    Button("Not Now") {
                        store.showFullDiskAccessPrompt = false
                    }
                    .frame(maxWidth: .infinity)

                    Button("Open Settings") {
                        CleanerService.openFullDiskAccessSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(20)
        }
    }

    private func confirmOverlay(_ target: CleanTarget) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { store.cancelConfirm() }

            VStack(alignment: .leading, spacing: 12) {
                Text(target.confirmationTitle)
                    .font(.headline)
                Text(target.name)
                    .font(.subheadline.weight(.medium))
                Text(target.confirmationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Cancel") {
                        store.cancelConfirm()
                    }
                    .keyboardShortcut(.cancelAction)
                    .frame(maxWidth: .infinity)

                    Button(target.confirmButtonTitle) {
                        store.confirmDelete(target, diskMonitor: diskMonitor)
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(target.isPermanent ? .red : .accentColor)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .frame(maxWidth: 340)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(20)
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
                    mediaStore.scan()
                    diskMonitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(store.isScanning ? 360 : 0))
                        .animation(
                            store.isScanning
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: store.isScanning
                        )
                }
                .buttonStyle(.borderless)
                .disabled(store.isScanning || store.pendingConfirmID != nil)
                .help("Rescan")
            }

            DiskSpaceStatusCard(monitor: diskMonitor)

            let cacheReclaim = store.totalReclaimable
            let mediaReclaim = mediaStore.totalBytes
            let combined = cacheReclaim + mediaReclaim
            if combined > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.secondary)
                        Text("Can reclaim \(ByteFormatting.string(from: combined))")
                            .font(.caption.weight(.semibold))
                            .contentTransition(.numericText())
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        if cacheReclaim > 0 {
                            Text("Caches \(store.totalReclaimableLabel)")
                        }
                        if mediaReclaim > 0 {
                            Text("Media \(mediaStore.totalBytesLabel)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        let cleanupItems = store.results.filter { !$0.target.isPermanent }
        let trashItems = store.results.filter(\.target.isPermanent)

        if store.isScanning, store.results.isEmpty, mediaStore.items.isEmpty {
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
                    sectionLabel("Media")
                    MediaCaptureSummaryRow()

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
                                Divider().padding(.leading, 14)
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 10)
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
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
