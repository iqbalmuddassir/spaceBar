import CoreGraphics

/// Squarified treemap (Bruls, Huizing & van Wijk). Plain rows would give long slivers for the
/// small targets; squarifying keeps every tile close to square so its area stays readable.
enum TreemapLayout {
    struct Tile<ID: Hashable>: Equatable {
        let id: ID
        let rect: CGRect
    }

    static func tiles<ID: Hashable>(
        for items: [(id: ID, weight: Double)],
        in bounds: CGRect
    ) -> [Tile<ID>] {
        let positive = items.filter { $0.weight > 0 }
        guard !positive.isEmpty, bounds.width > 0, bounds.height > 0 else { return [] }

        let totalWeight = positive.reduce(0) { $0 + $1.weight }
        let scale = (bounds.width * bounds.height) / totalWeight
        let sorted = positive
            .sorted { $0.weight > $1.weight }
            .map { (id: $0.id, area: $0.weight * scale) }

        var results: [Tile<ID>] = []
        var free = bounds
        var row: [(id: ID, area: Double)] = []
        var index = 0

        while index < sorted.count {
            let candidate = sorted[index]
            let side = Double(min(free.width, free.height))

            if row.isEmpty || worstRatio(row + [candidate], side: side) <= worstRatio(row, side: side) {
                row.append(candidate)
                index += 1
            } else {
                place(row: row, in: &free, into: &results)
                row = []
            }
        }
        if !row.isEmpty {
            place(row: row, in: &free, into: &results)
        }
        return results
    }

    /// Aspect ratio of the worst tile in the row — the value squarifying minimises.
    private static func worstRatio(_ row: [(id: some Hashable, area: Double)], side: Double) -> Double {
        guard !row.isEmpty, side > 0 else { return .greatestFiniteMagnitude }
        let sum = row.reduce(0) { $0 + $1.area }
        guard sum > 0 else { return .greatestFiniteMagnitude }
        let maxArea = row.map(\.area).max() ?? 0
        let minArea = row.map(\.area).min() ?? 0
        let sideSquared = side * side
        let sumSquared = sum * sum
        return max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    private static func place<ID: Hashable>(
        row: [(id: ID, area: Double)],
        in free: inout CGRect,
        into results: inout [Tile<ID>]
    ) {
        let sum = row.reduce(0) { $0 + $1.area }
        guard sum > 0 else { return }

        // Rows run along whichever edge is shorter, which is what keeps tiles square.
        let alongWidth = free.width >= free.height
        let thickness = CGFloat(sum) / (alongWidth ? free.height : free.width)
        var offset: CGFloat = alongWidth ? free.minY : free.minX

        for item in row {
            let length = CGFloat(item.area) / thickness
            let rect: CGRect = alongWidth
                ? CGRect(x: free.minX, y: offset, width: thickness, height: length)
                : CGRect(x: offset, y: free.minY, width: length, height: thickness)
            results.append(Tile(id: item.id, rect: rect))
            offset += length
        }

        if alongWidth {
            free = CGRect(
                x: free.minX + thickness,
                y: free.minY,
                width: max(0, free.width - thickness),
                height: free.height
            )
        } else {
            free = CGRect(
                x: free.minX,
                y: free.minY + thickness,
                width: free.width,
                height: max(0, free.height - thickness)
            )
        }
    }
}
