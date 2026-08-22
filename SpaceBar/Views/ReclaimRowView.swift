import SwiftUI

extension RecencyTemperature {
    var dotColor: Color {
        switch self {
        case .hot: .red
        case .warm: .orange
        case .cold: .green
        }
    }

    /// Cold is the safe, encouraging state here — the usual "stale is bad" mapping is inverted
    /// because forgotten bytes are exactly the ones worth deleting.
    var captionColor: Color {
        switch self {
        case .hot, .warm: dotColor
        case .cold: .secondary
        }
    }

    var accessibilityName: String {
        switch self {
        case .hot: "Hot — recently touched"
        case .warm: "Warm — somewhat recent"
        case .cold: "Cold — safe to clean by default"
        }
    }
}

struct RecencyLabel: View {
    let recency: Recency
    let staleAfter: TimeInterval

    var body: some View {
        let temperature = recency.temperature(staleAfter: staleAfter)
        HStack(spacing: 5) {
            Circle()
                .fill(temperature.dotColor)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Text(recency.caption(staleAfter: staleAfter))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption)
        .foregroundStyle(temperature.captionColor)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(recency.caption(staleAfter: staleAfter))
        .accessibilityValue(temperature.accessibilityName)
    }
}

/// The one row shared by every panel layout. Layouts differ in their header, never in this.
struct ReclaimRowView: View {
    let title: String
    let sizeLabel: String
    var recency: Recency?
    var fallbackCaption: String?
    var kindBadge: String?
    var isSelected: Bool
    var isSelectable: Bool = true
    var phase: RowPhase = .ready
    var errorMessage: String?
    let staleAfter: TimeInterval
    let density: RowDensity
    var onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let highlightShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            selectionControl

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                if let recency {
                    RecencyLabel(recency: recency, staleAfter: staleAfter)
                } else if let fallbackCaption {
                    Text(fallbackCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let kindBadge {
                Text(kindBadge.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay {
                        Capsule().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.8)
                    }
                    .accessibilityHidden(true)
            }

            Text(sizeLabel)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 64, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, density.verticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectable, phase != .deleting {
                onToggle()
            }
        }
        .background {
            if isSelected {
                Color.clear.liquidGlass(tint: .accentColor, in: highlightShape)
            }
        }
        .opacity(phase == .deleting ? 0.72 : 1)
        .animation(rowAnimation, value: isSelected)
        .animation(rowAnimation, value: phase)
        .animation(rowAnimation, value: sizeLabel)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelectable ? .isButton : [])
        .accessibilityHint(isSelectable ? "Double-tap to toggle selection" : "")
        .accessibilityAction {
            if isSelectable, phase != .deleting {
                onToggle()
            }
        }
    }

    private var rowAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)
    }

    private var rowAccessibilityLabel: String {
        var parts = [title, sizeLabel]
        if let recency {
            parts.append(recency.caption(staleAfter: staleAfter))
        } else if let fallbackCaption {
            parts.append(fallbackCaption)
        }
        if let kindBadge {
            parts.append(kindBadge)
        }
        if let errorMessage {
            parts.append(errorMessage)
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var selectionControl: some View {
        switch phase {
        case .deleting, .scanning:
            ProgressView()
                .controlSize(.small)
                .frame(width: 16)
                .accessibilityHidden(true)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body)
                .frame(width: 16)
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                .accessibilityHidden(true)
        case .idle, .ready, .error:
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.7))
                .frame(width: 16)
                .opacity(isSelectable ? 1 : 0.35)
                .accessibilityHidden(true)
        }
    }
}
