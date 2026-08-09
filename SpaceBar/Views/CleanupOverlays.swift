import SwiftUI

struct FullDiskAccessOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            DialogBackdrop { isPresented = false }

            PanelDialog(
                symbol: "lock.shield",
                title: "Full Disk Access Needed",
                message: "macOS blocked this cleanup. Enable Full Disk Access for SpaceBar to continue."
            ) {
                VStack(alignment: .leading, spacing: 7) {
                    step(1, "Open Privacy & Security → Full Disk Access")
                    step(2, "Enable SpaceBar, adding it with + if missing")
                    step(3, "Quit SpaceBar, reopen, then Clean again")
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("If SpaceBar is already enabled, toggle it off and on, then relaunch.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } actions: {
                DialogButton(title: "Not Now") {
                    isPresented = false
                }
                DialogButton(title: "Open Settings", isDefault: true) {
                    CleanerService.openFullDiskAccessSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16, height: 16)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One button deleting several things has to show the whole list, or it is not a real confirmation.
struct BatchCleanConfirmOverlay: View {
    let targets: [TargetScanResult]
    let totalBytes: UInt64
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var hasStrongConfirm: Bool {
        targets.contains { $0.target.requiresStrongConfirm || $0.target.isPermanent }
    }

    var body: some View {
        ZStack {
            DialogBackdrop(onTap: onCancel)

            PanelDialog(
                symbol: "arrow.down.circle",
                tint: hasStrongConfirm ? .red : .accentColor,
                title: "Delete \(targets.count) item\(targets.count == 1 ? "" : "s") permanently?",
                message: "Frees \(ByteFormatting.string(from: totalBytes))"
            ) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(targets) { result in
                        HStack(spacing: 8) {
                            Text(result.target.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(result.sizeLabel)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)

                if hasStrongConfirm {
                    Text("Includes items that cannot be regenerated. This cannot be undone.")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } actions: {
                DialogButton(title: "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                DialogButton(
                    title: "Delete",
                    isDefault: true,
                    tint: hasStrongConfirm ? .red : .accentColor,
                    action: onConfirm
                )
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

struct CleanupConfirmOverlay: View {
    let target: CleanTarget
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            DialogBackdrop(onTap: onCancel)

            PanelDialog(
                symbol: target.isPermanent ? "trash" : "exclamationmark.triangle",
                tint: accent,
                title: target.confirmationTitle,
                message: target.name
            ) {
                Text(target.safetyNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            } actions: {
                DialogButton(title: "Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                DialogButton(
                    title: target.confirmButtonTitle,
                    isDefault: true,
                    tint: accent,
                    action: onConfirm
                )
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var accent: Color {
        target.isPermanent || target.requiresStrongConfirm ? .red : .accentColor
    }
}
