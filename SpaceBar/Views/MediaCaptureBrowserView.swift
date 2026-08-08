import AppKit
import SwiftUI

struct MediaCaptureBrowserView: View {
    @EnvironmentObject private var mediaStore: MediaCaptureStore
    @EnvironmentObject private var diskMonitor: DiskSpaceMonitor

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            toolbar
            Divider()
            content
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay {
            if mediaStore.confirmDelete {
                confirmOverlay
            }
        }
        .animation(.snappy(duration: 0.2), value: mediaStore.confirmDelete)
    }

    private var header: some View {
        HStack {
            Button {
                mediaStore.closeBrowser()
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)

            Spacer()

            VStack(spacing: 2) {
                Text("Screenshots & Recordings")
                    .font(.headline)
                if mediaStore.totalBytes > 0 {
                    Text("Up to \(mediaStore.totalBytesLabel) reclaimable")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                } else {
                    Text(mediaStore.summaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                mediaStore.scan()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(mediaStore.isScanning || mediaStore.isDeleting)
            .help("Rescan")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("Select All") { mediaStore.selectAll() }
                .disabled(mediaStore.items.isEmpty || mediaStore.isDeleting)
            Button("Select None") { mediaStore.selectNone() }
                .disabled(mediaStore.selectedIDs.isEmpty || mediaStore.isDeleting)
            Button("Older than 30d") { mediaStore.selectOlderThan(days: 30) }
                .disabled(mediaStore.items.isEmpty || mediaStore.isDeleting)
            Spacer()
            if !mediaStore.selectedIDs.isEmpty {
                Text("Will free \(mediaStore.selectedBytesLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
            } else if mediaStore.totalBytes > 0 {
                Text("Select items to free up to \(mediaStore.totalBytesLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if mediaStore.isScanning && mediaStore.items.isEmpty {
            VStack(spacing: 10) {
                ProgressView()
                Text("Scanning Desktop, Pictures, Movies…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if mediaStore.items.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No screenshots or recordings found")
                    .font(.callout.weight(.medium))
                Text("Checked Desktop, Pictures, Movies, Downloads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(mediaStore.items) { item in
                    MediaCaptureRow(
                        item: item,
                        isSelected: mediaStore.selectedIDs.contains(item.id)
                    ) {
                        mediaStore.toggleSelection(item.id)
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                }
            }
            .listStyle(.plain)
            .disabled(mediaStore.isDeleting)
        }
    }

    private var footer: some View {
        HStack {
            if mediaStore.isDeleting {
                ProgressView()
                    .controlSize(.small)
                Text("Deleting…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let status = mediaStore.statusMessage {
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
                mediaStore.requestDeleteSelected()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(mediaStore.selectedIDs.isEmpty || mediaStore.isDeleting)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var confirmOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { mediaStore.cancelDelete() }

            VStack(alignment: .leading, spacing: 12) {
                Text("Delete \(mediaStore.selectedIDs.count) items?")
                    .font(.headline)
                Text("Permanently deletes \(mediaStore.selectedBytesLabel). Unchecked items are kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Cancel") { mediaStore.cancelDelete() }
                        .frame(maxWidth: .infinity)
                    Button("Delete") {
                        mediaStore.deleteSelected(diskMonitor: diskMonitor)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
            .frame(maxWidth: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .padding(20)
        }
    }
}

private struct MediaCaptureRow: View {
    let item: MediaCaptureItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .font(.title3)

                thumbnail
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        Text(item.kind.label)
                        Text("·")
                        Text(item.relativeAgeLabel)
                        Text("·")
                        Text(item.sizeLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .opacity(isSelected ? 1 : 0.72)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.kind == .screenshot, let image = NSImage(contentsOf: item.url) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.primary.opacity(0.06)
                Image(systemName: item.kind == .recording ? "video.fill" : "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MediaCaptureSummaryRow: View {
    @EnvironmentObject private var mediaStore: MediaCaptureStore

    var body: some View {
        Button {
            mediaStore.openBrowser()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Screenshots & Recordings")
                        .font(.system(.body, weight: .medium))
                    if mediaStore.isScanning {
                        Text("Scanning…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if mediaStore.totalBytes > 0 {
                        Text(mediaStore.reclaimHint)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.orange)
                        Text(mediaStore.summaryLabel)
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

                if mediaStore.totalBytes > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(mediaStore.totalBytesLabel)
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .monospacedDigit()
                        Text("reclaimable")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Review")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
