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
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct PanelFooter: View {
    let selectedBytes: UInt64
    let selectionSummary: String?
    let statusMessage: String?
    let isScanning: Bool
    let isBusy: Bool
    let targetCount: Int
    let onClean: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if selectedBytes > 0 {
                Button(action: onClean) {
                    Text("Clean selected · \(ByteFormatting.string(from: selectedBytes))")
                        .frame(maxWidth: .infinity)
                        .contentTransition(.numericText())
                }
                .liquidButtonStyle(prominent: true)
                .disabled(isBusy)

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

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .liquidChipButtonStyle()
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
