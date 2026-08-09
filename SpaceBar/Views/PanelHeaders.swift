import SwiftUI

/// Free / reclaimable / used as one object: reclaimable is drawn inside the used portion,
/// because that is literally where those bytes are.
struct CapacityMeter: View {
    let usedFraction: Double
    let reclaimableFraction: Double
    let levelColor: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let reclaim = min(reclaimableFraction, usedFraction)
            let plainUsed = max(0, usedFraction - reclaim)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.primary.opacity(0.28))
                    .frame(width: width * plainUsed)
                Rectangle()
                    .fill(reclaimableFill)
                    .frame(width: width * reclaim)
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: usedFraction)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: reclaimableFraction)
        }
        .frame(height: height)
        .clipShape(Capsule())
    }

    private var reclaimableFill: LinearGradient {
        LinearGradient(
            colors: [Color.orange.opacity(0.95), Color.orange.opacity(0.7)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct GaugeHeader: View {
    @ObservedObject var monitor: DiskSpaceMonitor
    let reclaimableBytes: UInt64

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        "\(monitor.freeSpaceLabel) free of \(ByteFormatting.compactFreeSpace(from: monitor.totalBytes))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(headline)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Spacer()
                Text(monitor.freePercentLabel)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(monitor.level.color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            CapacityMeter(
                usedFraction: 1 - monitor.freeFraction,
                reclaimableFraction: reclaimableFraction,
                levelColor: monitor.level.color
            )

            HStack(spacing: 12) {
                Text(monitor.level.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(monitor.level.color)
                Spacer()
                if reclaimableBytes > 0 {
                    HStack(spacing: 5) {
                        Capsule()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("reclaimable")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .liquidGlass(tint: monitor.level.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var headline: String {
        reclaimableBytes > 0
            ? "Recover up to \(ByteFormatting.string(from: reclaimableBytes))"
            : "Nothing to reclaim"
    }

    private var reclaimableFraction: Double {
        guard monitor.totalBytes > 0 else { return 0 }
        return Double(reclaimableBytes) / Double(monitor.totalBytes)
    }
}

/// Ledger's header: the same meter, one line tall, so the rows start as high as possible.
struct LedgerHeader: View {
    @ObservedObject var monitor: DiskSpaceMonitor
    let reclaimableBytes: UInt64
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CapacityMeter(
                usedFraction: 1 - monitor.freeFraction,
                reclaimableFraction: monitor.totalBytes > 0
                    ? Double(reclaimableBytes) / Double(monitor.totalBytes)
                    : 0,
                levelColor: monitor.level.color,
                height: 6
            )
            HStack(spacing: 6) {
                Text(ByteFormatting.string(from: reclaimableBytes))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text("reclaimable across \(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(monitor.freeSpaceLabel) free · \(monitor.freePercentLabel)")
                    .font(.caption)
                    .foregroundStyle(monitor.level == .healthy ? Color.secondary : monitor.level.color)
                    .monospacedDigit()
            }
        }
    }
}
