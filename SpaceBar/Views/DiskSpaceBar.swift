import SwiftUI

struct DiskSpaceBar: View {
    let fraction: Double
    let color: Color
    var height: CGFloat = 6
    var width: CGFloat? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(height, w * fraction))
                    .animation(.snappy(duration: 0.35), value: fraction)
                    .animation(.easeInOut(duration: 0.25), value: color)
            }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: width == nil ? .infinity : width)
    }
}

struct DiskSpaceStatusCard: View {
    @ObservedObject var monitor: DiskSpaceMonitor

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
        .padding(12)
        .background(monitor.level.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(monitor.level.color.opacity(0.22), lineWidth: 1)
        )
    }
}
