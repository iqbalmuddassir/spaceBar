import SwiftUI

struct DiskSpaceBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6
    var width: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.85), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, barWidth * fraction))
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: fraction)
                    .animation(.easeInOut(duration: 0.25), value: color)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : width)
    }
}

struct DiskSpaceStatusCard: View {
    @ObservedObject var monitor: DiskSpaceMonitor

    private let cardShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(monitor.freeSpaceLabel)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("free")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(monitor.freePercentLabel)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(monitor.level.color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            DiskSpaceBar(
                fraction: monitor.freeFraction,
                color: monitor.level.color,
                height: 8
            )

            HStack {
                Text(monitor.level.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(monitor.level.color)
                Spacer()
                Text("of \(ByteFormatting.compactFreeSpace(from: monitor.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(tint: monitor.level.color, in: cardShape)
    }
}
