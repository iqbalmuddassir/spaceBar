import AppKit
import SwiftUI

struct ReviewableFilesBrowserView: View {
    @ObservedObject var store: ReviewableFilesStore
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.liquidGlassNamespace) private var glassNamespace

    private var navigationGlassID: String {
        "reviewable-nav-\(store.category.rawValue)"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            toolbar
            content
            footer
        }
        .background {
            PanelGlassBackground(cornerRadius: 18)
        }
        .overlay {
            if store.confirmDelete {
                confirmOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(LiquidGlassMotion.overlay(reduceMotion), value: store.confirmDelete)
    }

    private var header: some View {
        HStack {
            Button {
                store.closeBrowser()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .liquidPillButtonStyle()
            .liquidGlassEffectID(navigationGlassID, in: glassNamespace)

            Spacer()

            VStack(spacing: 3) {
                Text(store.title)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if store.totalBytes > 0 {
                    Text("Up to \(store.totalBytesLabel) reclaimable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text(store.summaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.scan()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.body.weight(.semibold))
            }
            .liquidChipButtonStyle()
            .disabled(store.isScanning || store.isDeleting)
            .help("Rescan")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("Select All") { store.selectAll() }
                .disabled(store.files.isEmpty || store.isDeleting)
                .liquidPillButtonStyle()
            Button("Select None") { store.selectNone() }
                .disabled(store.selectedIDs.isEmpty || store.isDeleting)
                .liquidPillButtonStyle()
            Button("Older than 30d") { store.selectOlderThan(days: 30) }
                .disabled(store.files.isEmpty || store.isDeleting)
                .liquidPillButtonStyle()
            Spacer(minLength: 8)
            if !store.selectedIDs.isEmpty {
                Text("Will free \(store.selectedBytesLabel)")
                    .contentTransition(.numericText())
                    .liquidPillLabel()
            } else if store.totalBytes > 0 {
                Text("Select items to free up to \(store.totalBytesLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isScanning, store.files.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text(store.category.scanningLocationsDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.files.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: store.category.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(store.category.emptyStatus)
                    .font(.callout.weight(.medium))
                Text(store.category.checkedLocationsDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(store.files) { file in
                    ReviewableFileRow(
                        file: file,
                        isSelected: store.selectedIDs.contains(file.id)
                    ) {
                        store.toggleSelection(file.id)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .disabled(store.isDeleting)
        }
    }

    private var footer: some View {
        HStack {
            if store.isDeleting {
                ProgressView()
                    .controlSize(.small)
                Text("Deleting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let status = store.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Checked = delete · unchecked = keep")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Delete Selected") {
                store.requestDeleteSelected()
            }
            .liquidButtonStyle(prominent: true, tint: .red)
            .disabled(store.selectedIDs.isEmpty || store.isDeleting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Divider().opacity(0.55)
        }
    }

    private var confirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture { store.cancelDelete() }

            VStack(alignment: .leading, spacing: 12) {
                Text("Delete \(store.selectedIDs.count) items?")
                    .font(.headline)
                Text("Permanently deletes \(store.selectedBytesLabel). Unchecked items are kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Cancel") { store.cancelDelete() }
                        .liquidButtonStyle()
                        .frame(maxWidth: .infinity)
                    Button("Delete") {
                        store.deleteSelected(diskMonitor: diskMonitor)
                    }
                    .liquidButtonStyle(prominent: true, tint: .red)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(18)
            .frame(maxWidth: 320)
            .liquidDialogSurface(tint: .red)
            .padding(20)
        }
    }
}

private struct ReviewableFileRow: View {
    let file: ReviewableFile
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)
                    .symbolEffect(.bounce, value: isSelected)

                ReviewableFileThumbnail(file: file)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(file.kind.label)
                        Text("·")
                        Text(file.relativeAgeLabel)
                        Text("·")
                        Text(file.sizeLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .opacity(isSelected ? 1 : 0.72)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewableFileThumbnail: View {
    let file: ReviewableFile
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color.primary.opacity(0.06)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: Self.placeholderSymbol(for: file.kind))
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: file.url) {
            guard file.kind == .screenshot else {
                image = nil
                return
            }
            let url = file.url
            image = await Task.detached(priority: .utility) {
                NSImage(contentsOf: url)
            }.value
        }
    }

    private static func placeholderSymbol(for kind: ReviewableFileKind) -> String {
        switch kind {
        case .recording: "video.fill"
        case .installer: "shippingbox.fill"
        case .screenshot: "photo"
        }
    }
}

struct ReviewableFilesSummaryRow: View {
    @ObservedObject var store: ReviewableFilesStore
    @Environment(\.liquidGlassNamespace) private var glassNamespace

    private var navigationGlassID: String {
        "reviewable-nav-\(store.category.rawValue)"
    }

    var body: some View {
        Button {
            store.openBrowser()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.title)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if store.isScanning {
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if store.totalBytes > 0 {
                        Text(store.reclaimHint)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(store.summaryLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("None found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if store.totalBytes > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(store.totalBytesLabel)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Text("reclaimable")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Review")
                    .liquidPillLabel()
                    .liquidGlassEffectID(navigationGlassID, in: glassNamespace)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
