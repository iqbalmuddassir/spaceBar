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
