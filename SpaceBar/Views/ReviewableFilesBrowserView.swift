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
        .animation(.snappy(duration: 0.25), value: store.sortOrder)
        .animation(.snappy(duration: 0.25), value: store.kindFilter)
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
            .keyboardShortcut(.cancelAction)

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
                Group {
                    if store.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.semibold))
                    }
                }
                .frame(width: 16, height: 16)
            }
            .liquidChipButtonStyle()
            .disabled(store.isScanning || store.isDeleting)
            .help("Rescan")
            .accessibilityLabel("Rescan \(store.title)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(store.areAllVisibleSelected ? "Select None" : "Select All") {
                    store.toggleSelectAll()
                }
                .disabled(store.visibleFiles.isEmpty || store.isDeleting)
                .liquidPillButtonStyle()
                .keyboardShortcut("a", modifiers: .command)

                Button("Older than 30d") { store.selectOlderThan(days: 30) }
                    .disabled(store.visibleFiles.isEmpty || store.isDeleting)
                    .liquidPillButtonStyle()

                Spacer(minLength: 8)

                sortPicker
            }

            if !store.availableKindFilters.isEmpty {
                kindFilterRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $store.sortOrder) {
            ForEach(ReviewableSortOrder.allCases) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
        .disabled(store.isDeleting)
        .help("Sort order")
        .accessibilityLabel("Sort order")
    }

    private var kindFilterRow: some View {
        HStack(spacing: 6) {
            filterChip(title: "All", count: store.files.count, isOn: store.kindFilter == nil) {
                store.kindFilter = nil
            }
            ForEach(store.availableKindFilters) { kind in
                filterChip(
                    title: kind.pluralLabel.capitalized,
                    count: store.count(of: kind),
                    isOn: store.kindFilter == kind
                ) {
                    store.kindFilter = store.kindFilter == kind ? nil : kind
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func filterChip(
        title: String,
        count: Int,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.medium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background {
            Capsule().fill(isOn ? Color.accentColor.opacity(0.20) : Color.primary.opacity(0.07))
        }
        .overlay {
            Capsule().strokeBorder(
                isOn ? Color.accentColor.opacity(0.55) : Color.clear,
                lineWidth: 1
            )
        }
        .foregroundStyle(isOn ? Color.accentColor : .primary)
        .disabled(store.isDeleting)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var content: some View {
        if store.isScanning, store.files.isEmpty {
            centeredState {
                ProgressView()
                Text(store.category.scanningLocationsDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if store.files.isEmpty {
            centeredState {
                Image(systemName: store.category.symbolName)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(store.category.emptyStatus)
                    .font(.callout.weight(.medium))
                Text(store.category.checkedLocationsDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if store.visibleFiles.isEmpty {
            centeredState {
                Text("Nothing matches this filter")
                    .font(.callout.weight(.medium))
                Button("Show all") { store.kindFilter = nil }
                    .liquidPillButtonStyle()
            }
        } else {
            fileList
        }
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.visibleFiles) { file in
                    ReviewableFileRow(
                        file: file,
                        isSelected: store.selectedIDs.contains(file.id),
                        onToggle: { store.toggleSelection(file.id) },
                        onReveal: { store.revealInFinder(file) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .disabled(store.isDeleting)
    }

    private func centeredState(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            footerStatus
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button(deleteButtonTitle) {
                store.requestDeleteSelected()
            }
            .liquidButtonStyle(prominent: true, tint: .red)
            .disabled(store.selectedIDs.isEmpty || store.isDeleting)
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Divider().opacity(0.55)
        }
    }

    private var deleteButtonTitle: String {
        store.selectedIDs.isEmpty ? "Delete" : "Delete \(store.selectedIDs.count) · \(store.selectedBytesLabel)"
    }

    @ViewBuilder
    private var footerStatus: some View {
        if store.isDeleting {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Deleting…")
            }
        } else if !store.selectedIDs.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(store.selectedIDs.count) of \(store.files.count) selected")
                if store.hasSelectionOutsideFilter {
                    Text("Includes items hidden by the current filter")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } else if let status = store.statusMessage {
            Text(status)
        } else {
            Text("Checked = delete · unchecked = keep")
        }
    }

    private var confirmOverlay: some View {
        ZStack {
            DialogBackdrop { store.cancelDelete() }

            PanelDialog(
                symbol: "trash",
                tint: .red,
                title: store.selectedIDs.count == 1 ? "Delete 1 item?" : "Delete \(store.selectedIDs.count) items?",
                message: "Frees \(store.selectedBytesLabel). Unchecked items are kept."
            ) {
                Text("This cannot be undone.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } actions: {
                DialogButton(title: "Cancel") { store.cancelDelete() }
                    .keyboardShortcut(.cancelAction)
                DialogButton(title: "Delete", isDefault: true, tint: .red) {
                    store.deleteSelected(diskMonitor: diskMonitor)
                }
                .keyboardShortcut(.defaultAction)
            }
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
            HStack(spacing: 10) {
                Image(systemName: "chevron.right.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)
                    .liquidGlassEffectID(navigationGlassID, in: glassNamespace)

                VStack(alignment: .leading, spacing: 3) {
                    Text(store.title)
                        .font(.system(.body, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Group {
                        if store.isScanning {
                            Text("Scanning…")
                        } else if store.totalBytes > 0 {
                            Text(store.summaryLabel)
                        } else {
                            Text("None found")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                Text("REVIEW")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay {
                        Capsule().strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 0.8)
                    }

                if store.totalBytes > 0 {
                    Text(store.totalBytesLabel)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 64, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(store.title). \(store.summaryLabel). Opens the review list.")
    }
}
