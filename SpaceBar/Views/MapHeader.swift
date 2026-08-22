import SwiftUI

struct ReclaimMapItem: Identifiable, Equatable {
    let id: String
    let name: String
    let bytes: UInt64
    var temperature: RecencyTemperature?
    var isSelected: Bool
    var isReview: Bool
    var isAggregate: Bool = false
}

/// Area is bytes, colour is recency — the same cold/warm/hot scale the rows use, so the map
/// and the list tell one story. Tiles are the selection, not a picture of it.
struct MapHeader: View {
    let items: [ReclaimMapItem]
    let onToggle: (String) -> Void
    let onOpenReview: (String) -> Void

    /// Tall enough that the smallest tile lands closer to square than to a sliver — a very wide,
    /// short rect forces the remainder into an unlabelled column whatever the merge threshold is.
    static let height: CGFloat = 164

    /// Only the item count matters: one or two tiles say less than a bar does, but proportion
    /// reads the same whether the total is 40 MB or 40 GB, so there is no byte floor.
    static let minimumItems = 3

    static func isWorthDrawing(_ items: [ReclaimMapItem]) -> Bool {
        items.filter { $0.bytes > 0 }.count >= minimumItems
    }

    static var fallbackExplanation: String {
        "Map needs at least \(minimumItems) items — showing the meter until then."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(ByteFormatting.string(from: totalBytes)) reclaimable — sized by how much each frees")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            GeometryReader { geo in
                let tiles = TreemapLayout.tiles(
                    for: displayItems.map { (id: $0.id, weight: Double($0.bytes)) },
                    in: CGRect(origin: .zero, size: geo.size)
                )
                ZStack(alignment: .topLeading) {
                    ForEach(tiles, id: \.id) { tile in
                        if let item = displayItems.first(where: { $0.id == tile.id }) {
                            MapTile(item: item, size: tile.rect.size)
                                .frame(width: max(0, tile.rect.width - 3), height: max(0, tile.rect.height - 3))
                                .offset(x: tile.rect.minX, y: tile.rect.minY)
                                .onTapGesture { activate(item) }
                        }
                    }
                }
            }
            .frame(height: Self.height)

            HStack(spacing: 12) {
                legendSwatch(.green, "Safe to wipe")
                legendSwatch(.orange, "Used recently")
                legendSwatch(.accentColor, "Review first")
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var totalBytes: UInt64 {
        items.reduce(0) { $0 + $1.bytes }
    }

    /// Tiles below a readable size are folded into one, rather than drawn as unlabelled slivers.
    private var displayItems: [ReclaimMapItem] {
        let total = totalBytes
        guard total > 0 else { return items }
        // 6% of the total is roughly the smallest tile that can still carry a readable size
        // label at this header height.
        let threshold = Double(total) * 0.06
        let major = items.filter { Double($0.bytes) >= threshold }
        let minor = items.filter { Double($0.bytes) < threshold }

        guard minor.count > 1 else { return items }
        let merged = ReclaimMapItem(
            id: "map-everything-else",
            name: "Everything else",
            bytes: minor.reduce(0) { $0 + $1.bytes },
            temperature: nil,
            isSelected: false,
            isReview: false,
            isAggregate: true
        )
        return major + [merged]
    }

    private func activate(_ item: ReclaimMapItem) {
        guard !item.isAggregate else { return }
        if item.isReview {
            onOpenReview(item.id)
        } else {
            onToggle(item.id)
        }
    }

    private func legendSwatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

struct MapTile: View {
    let item: ReclaimMapItem
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tint: Color {
        if item.isAggregate {
            return .secondary
        }
        if item.isReview {
            return .accentColor
        }
        switch item.temperature {
        case .hot: return .red
        case .warm: return .orange
        case .cold, .none: return .green
        }
    }

    private var showsName: Bool {
        size.width >= 62 && size.height >= 38
    }

    private var showsSize: Bool {
        size.height >= 20 && size.width >= 30
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            if showsName {
                Text(item.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            if showsSize {
                Text(ByteFormatting.string(from: item.bytes))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(item.isSelected ? tint : Color.secondary)
        .background {
            shape.fill(tint.opacity(item.isSelected ? 0.26 : 0.07))
        }
        .overlay {
            shape.strokeBorder(
                tint.opacity(item.isSelected ? 0.75 : 0.30),
                lineWidth: item.isSelected ? 1.4 : 0.8
            )
        }
        .overlay(alignment: .topTrailing) {
            if item.isSelected, size.width >= 42, size.height >= 30 {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint)
                    .padding(4)
            }
        }
        .contentShape(shape)
        .animation(LiquidGlassMotion.selection(reduceMotion), value: item.isSelected)
        .help(item.isAggregate ? item.name : "\(item.name) — \(ByteFormatting.string(from: item.bytes))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mapTileAccessibilityLabel)
        .accessibilityValue(item.isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
    }

    private var mapTileAccessibilityLabel: String {
        var parts = [item.name, ByteFormatting.string(from: item.bytes)]
        if item.isAggregate {
            parts.append("aggregated small items")
        } else if item.isReview {
            parts.append("review category")
        } else if let temperature = item.temperature {
            parts.append(temperature.accessibilityName)
        } else {
            parts.append("Age unknown")
        }
        return parts.joined(separator: ", ")
    }
}
