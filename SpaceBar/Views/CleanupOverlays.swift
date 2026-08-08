import SwiftUI

struct FullDiskAccessOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.40)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

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
                        isPresented = false
                    }
                    .liquidButtonStyle()
                    .frame(maxWidth: .infinity)

                    Button("Open Settings") {
                        CleanerService.openFullDiskAccessSettings()
                    }
                    .liquidButtonStyle(prominent: true)
                    .frame(maxWidth: .infinity)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(18)
            .frame(maxWidth: 340)
            .liquidDialogSurface()
            .padding(20)
        }
    }
}

struct CleanupConfirmOverlay: View {
    let target: CleanTarget
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.40)
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

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
                    Button("Cancel", action: onCancel)
                        .keyboardShortcut(.cancelAction)
                        .liquidButtonStyle()
                        .frame(maxWidth: .infinity)

                    Button(target.confirmButtonTitle, action: onConfirm)
                        .keyboardShortcut(.defaultAction)
                        .liquidButtonStyle(
                            prominent: true,
                            tint: target.isPermanent ? .red : .accentColor
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
            .frame(maxWidth: 340)
            .liquidDialogSurface(tint: target.isPermanent ? .red : nil)
            .padding(20)
        }
    }
}
