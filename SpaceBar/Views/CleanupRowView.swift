import SwiftUI

struct CleanupRowView: View {
    let result: TargetScanResult
    var isConfirming: Bool = false
    let onDelete: () -> Void

    private let highlightShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.target.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let stale = result.staleDescription {
                        Text(stale)
                            .lineLimit(1)
                    } else if isCommandBased {
                        Text("command cleanup")
                    } else {
                        Text(result.target.subtitle)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if case let .error(message) = result.phase {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(result.sizeLabel)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(minWidth: 64, alignment: .trailing)

            trailingControl
                .frame(width: 78, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            if isConfirming {
                Color.clear
                    .liquidGlass(tint: .accentColor, in: highlightShape)
            }
        }
        .opacity(result.phase == .deleting ? 0.72 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: result.phase)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: result.sizeLabel)
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isConfirming)
    }

    private var isCommandBased: Bool {
        switch result.target.strategy {
        case .simctlDeleteUnavailable, .dockerBuilderPrune:
            true
        default:
            false
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch result.phase {
        case .scanning, .deleting:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
                .transition(.scale.combined(with: .opacity))
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .idle, .ready, .error:
            Button(result.target.isPermanent ? "Empty" : "Clean") {
                onDelete()
            }
            .liquidPillButtonStyle(
                tint: result.target.isPermanent ? .red : .accentColor
            )
            .disabled(isConfirming)
        }
    }
}
