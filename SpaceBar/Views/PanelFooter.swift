import AppKit
import SwiftUI

struct ReclaimListHeader: View {
    let allSelected: Bool
    let onToggleAll: () -> Void

    var body: some View {
        HStack {
            Text("Reclaimable")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
            Spacer()
            Button(allSelected ? "Select none" : "Select all", action: onToggleAll)
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(allSelected ? "Select none" : "Select all reclaimable targets")
                .accessibilityHint(
                    allSelected
                        ? "Clears selection for cache targets. Trash stays opted out."
                        : "Selects all cache targets. Trash stays opted out."
                )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct PanelFooter: View {
    let selectedBytes: UInt64
    let selectedCount: Int
    let selectionSummary: String?
    let statusMessage: String?
    let isScanning: Bool
    let isBusy: Bool
    let targetCount: Int
    let onClean: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    private var cleanLabel: String {
        if selectedBytes > 0 {
            return "Clean selected · \(ByteFormatting.string(from: selectedBytes))"
        }
        return "Clean selected · \(selectedCount) item\(selectedCount == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(spacing: 8) {
            if selectedCount > 0 {
                Button(action: onClean) {
                    Text(cleanLabel)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                }
                .liquidButtonStyle(prominent: true)
                .disabled(isBusy)
                .accessibilityLabel(cleanLabel)
                .accessibilityHint("Permanently deletes the selected reclaim targets after confirmation")

                if let selectionSummary {
                    Text(selectionSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(spacing: 8) {
                Group {
                    if let statusMessage {
                        Text(statusMessage).lineLimit(2)
                    } else if isScanning {
                        Text("Updating sizes…")
                    } else {
                        Text("\(targetCount) targets")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .liquidChipButtonStyle()
                .help("Settings")
                .accessibilityLabel("Settings")

                Button("Quit", action: onQuit)
                    .liquidChipButtonStyle()
                    .accessibilityLabel("Quit SpaceBar")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Divider().opacity(0.55)
        }
    }
}
