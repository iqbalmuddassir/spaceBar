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
                .keyboardShortcut(.cancelAction)
                DialogButton(title: "Open Settings", isDefault: true) {
                    CleanerService.openFullDiskAccessSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        permissionStep(number, text)
    }
}

struct AutomationAccessOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            DialogBackdrop { isPresented = false }

            PanelDialog(
                symbol: "hand.raised.fill",
                title: "Automation Access Needed",
                message: """
                Emptying Trash needs permission to control Finder. \
                Enable Automation for SpaceBar to continue.
                """
            ) {
                VStack(alignment: .leading, spacing: 7) {
                    permissionStep(1, "Open Privacy & Security → Automation")
                    permissionStep(2, "Find SpaceBar and enable Finder")
                    permissionStep(3, "Return here and Empty Trash again")
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(
                    """
                    SpaceBar can also try a direct Trash delete when Finder Automation \
                    is denied; that still needs Full Disk Access.
                    """
                )
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            } actions: {
                DialogButton(title: "Not Now") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                DialogButton(title: "Open Settings", isDefault: true) {
                    CleanerService.openAutomationSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

private func permissionStep(_ number: Int, _ text: String) -> some View {
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

/// One button deleting several things has to show the whole list, or it is not a real confirmation.
struct BatchCleanConfirmOverlay: View {
    let targets: [TargetScanResult]
    let totalBytes: UInt64
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var hasStrongConfirm: Bool {
        targets.contains { $0.target.requiresStrongConfirm || $0.target.isPermanent }
    }

    private var strongWarnings: [String] {
        targets
            .filter { $0.target.requiresStrongConfirm || $0.target.isPermanent }
            .map(\.target.confirmationMessage)
    }

    var body: some View {
        ZStack {
            DialogBackdrop(onTap: onCancel)

            PanelDialog(
                symbol: "arrow.down.circle",
                tint: hasStrongConfirm ? .red : .accentColor,
                title: "Delete \(targets.count) item\(targets.count == 1 ? "" : "s") permanently?",
                message: totalBytes > 0
                    ? "Frees \(ByteFormatting.string(from: totalBytes))"
                    : "Selected items will be removed permanently"
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
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(strongWarnings.enumerated()), id: \.offset) { _, warning in
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

struct FirstRunPrimerOverlay: View {
    @Binding var isPresented: Bool
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            DialogBackdrop {
                onContinue()
            }

            PanelDialog(
                symbol: "sparkles",
                title: "Before you clean",
                message: """
                SpaceBar reclaims regenerable clutter from your Mac. \
                Deletes are permanent so space frees immediately.
                """
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    primerStep("Some Library caches need Full Disk Access.")
                    primerStep("Empty Trash needs Automation access to Finder.")
                    primerStep("Only tick what you are ready to remove — caches rebuild; personal files do not.")
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            } actions: {
                DialogButton(title: "Open FDA Settings") {
                    CleanerService.openFullDiskAccessSettings()
                }
                DialogButton(title: "Continue", isDefault: true, action: onContinue)
                    .keyboardShortcut(.defaultAction)
                    .keyboardShortcut(.cancelAction) // Escape also dismisses the one-time primer
            }
        }
    }

    private func primerStep(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
