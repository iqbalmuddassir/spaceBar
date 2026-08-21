import SwiftUI

struct PanelDialog<Actions: View, Details: View>: View {
    let symbol: String
    var tint: Color = .accentColor
    let title: String
    let message: String
    @ViewBuilder var details: () -> Details
    @ViewBuilder var actions: () -> Actions

    @AccessibilityFocusState private var isTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .padding(.bottom, 2)
                .accessibilityHidden(true)

                Text(title)
                    .font(.system(.title3, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($isTitleFocused)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                details()
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            HStack(spacing: 10) {
                actions()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .frame(width: 310)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.32), radius: 26, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            // Skip under XCTest: AccessibilityFocusState during NSHostingView layout can trap
            // the snapshot host (Signal 5) and block the suite on the crash prompt.
            guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
                return
            }
            // Defer so the overlay is in the hierarchy before VoiceOver moves focus.
            DispatchQueue.main.async {
                isTitleFocused = true
            }
        }
    }
}

extension PanelDialog where Details == EmptyView {
    init(
        symbol: String,
        tint: Color = .accentColor,
        title: String,
        message: String,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.init(
            symbol: symbol,
            tint: tint,
            title: title,
            message: message,
            details: { EmptyView() },
            actions: actions
        )
    }
}

struct DialogBackdrop: View {
    let onTap: () -> Void

    var body: some View {
        Rectangle()
            .fill(.black.opacity(0.28))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            // Keep VoiceOver on the dialog, not the dimmed chrome behind it.
            .accessibilityHidden(true)
    }
}

struct DialogButton: View {
    let title: String
    var isDefault = false
    var tint: Color = .accentColor
    let action: () -> Void

    private static let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.body, weight: isDefault ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDefault ? Color.white : Color.primary)
        .background {
            Self.shape.fill(isDefault ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.10)))
        }
        .overlay {
            Self.shape.strokeBorder(Color.primary.opacity(isDefault ? 0 : 0.12), lineWidth: 0.8)
        }
        .accessibilityLabel(title)
    }
}
