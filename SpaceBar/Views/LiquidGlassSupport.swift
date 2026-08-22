import SwiftUI

enum LiquidGlassMotion {
    static func panel(_ reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.18)
            : .spring(response: 0.35, dampingFraction: 0.82)
    }

    static func overlay(_ reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeInOut(duration: 0.16)
            : .spring(response: 0.32, dampingFraction: 0.86)
    }

    /// Content springs (meters, tiles, rows). Returns `nil` when Reduce Motion is on.
    static func content(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)
    }

    static func snappy(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .snappy(duration: 0.25)
    }

    static func selection(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.85)
    }
}

enum LiquidGlassRuntime {
    @MainActor
    static var testOverride: Bool?

    @MainActor
    static var usesLiquidGlassChrome: Bool {
        guard #available(macOS 26, *) else { return false }
        if let testOverride {
            return testOverride
        }
        return true
    }

    @MainActor
    static var allowsGlassEffect: Bool {
        guard usesLiquidGlassChrome else { return false }
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    @MainActor
    static func withChrome(_ enabled: Bool, operation: () -> Void) {
        let previous = testOverride
        testOverride = enabled
        defer { testOverride = previous }
        operation()
    }
}

struct LiquidGlassContainer<Content: View>: View {
    var spacing: CGFloat?
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26, *), LiquidGlassRuntime.allowsGlassEffect {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

struct PanelGlassBackground: View {
    var cornerRadius: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(.regularMaterial)
            if #available(macOS 26, *), LiquidGlassRuntime.allowsGlassEffect {
                shape
                    .fill(Color.primary.opacity(0.04))
                    .glassEffect(.regular, in: shape)
            } else if LiquidGlassRuntime.usesLiquidGlassChrome {
                shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
            }
        }
    }
}

struct LiquidActionButtonStyle: ButtonStyle {
    var prominent: Bool = false
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        let accent = tint ?? Color.accentColor
        configuration.label
            .font(.system(.caption).weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(prominent ? Color.white : accent)
            .background {
                buttonChrome(accent: accent, pressed: configuration.isPressed)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }

    @ViewBuilder
    private func buttonChrome(accent: Color, pressed: Bool) -> some View {
        let shape = Capsule(style: .continuous)
        if prominent {
            shape.fill(accent.opacity(pressed ? 0.88 : 1))
        } else {
            shape
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(shape.strokeBorder(accent.opacity(0.75), lineWidth: 1.2))
        }
    }
}

struct LiquidChipButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint ?? Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                chipChrome(pressed: configuration.isPressed)
            }
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }

    private func chipChrome(pressed: Bool) -> some View {
        let shape = Capsule(style: .continuous)
        return shape
            .fill(Color.primary.opacity(pressed ? 0.18 : 0.12))
            .overlay(shape.strokeBorder(Color.primary.opacity(0.30), lineWidth: 0.9))
    }
}

struct LiquidPillButtonStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .liquidGlass(tint: tint, interactive: true, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

private struct LiquidGlassNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var liquidGlassNamespace: Namespace.ID? {
        get { self[LiquidGlassNamespaceKey.self] }
        set { self[LiquidGlassNamespaceKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func liquidGlass(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: some InsettableShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    ) -> some View {
        if LiquidGlassRuntime.usesLiquidGlassChrome {
            if #available(macOS 26, *), LiquidGlassRuntime.allowsGlassEffect {
                background {
                    glassFill(tint: tint, interactive: interactive, in: shape)
                }
            } else {
                background(.regularMaterial, in: shape)
                    .overlay {
                        if let tint {
                            shape.fill(tint.opacity(0.12))
                        }
                    }
                    .overlay {
                        shape.strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.8)
                    }
            }
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay {
                    if let tint {
                        shape.fill(tint.opacity(0.12))
                    }
                }
        }
    }

    @ViewBuilder
    func liquidGlassEffectID(_ id: some Hashable & Sendable, in namespace: Namespace.ID?) -> some View {
        if #available(macOS 26, *), LiquidGlassRuntime.allowsGlassEffect, let namespace {
            glassEffectID(id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func liquidGlassTransitionMaterialize() -> some View {
        if #available(macOS 26, *), LiquidGlassRuntime.allowsGlassEffect {
            glassEffectTransition(.materialize)
        } else {
            self
        }
    }

    func liquidButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
        buttonStyle(LiquidActionButtonStyle(prominent: prominent, tint: tint))
    }

    func liquidChipButtonStyle(tint: Color? = nil) -> some View {
        buttonStyle(LiquidChipButtonStyle(tint: tint))
    }

    func liquidPillButtonStyle(tint: Color = .accentColor) -> some View {
        buttonStyle(LiquidPillButtonStyle(tint: tint))
    }

    func liquidPillLabel(tint: Color = .accentColor) -> some View {
        font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tint)
            .liquidGlass(tint: tint, interactive: true, in: Capsule())
    }

    func liquidDialogSurface(
        tint: Color? = nil,
        cornerRadius: CGFloat = 16
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return background {
            ZStack {
                shape.fill(Color(nsColor: .windowBackgroundColor))
                shape.fill(.regularMaterial)
                if let tint {
                    shape.fill(tint.opacity(0.10))
                }
            }
        }
        .overlay {
            shape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        }
        .clipShape(shape)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
    }

    @available(macOS 26, *)
    private func glassFill(
        tint: Color?,
        interactive: Bool,
        in shape: some InsettableShape
    ) -> some View {
        var glass = Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return ZStack {
            shape.fill(.regularMaterial)
            if let tint {
                shape.fill(tint.opacity(0.12))
            }
            shape
                .fill(Color.clear)
                .glassEffect(glass, in: shape)
        }
    }
}
