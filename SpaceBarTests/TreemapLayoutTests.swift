import CoreGraphics
import XCTest
@testable import SpaceBar

final class TreemapLayoutTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 400, height: 120)

    func testTilesCoverTheBoundsWithoutOverlapping() {
        let tiles = TreemapLayout.tiles(
            for: [("a", 50), ("b", 25), ("c", 15), ("d", 10)],
            in: bounds
        )

        XCTAssertEqual(tiles.count, 4)

        let covered = tiles.reduce(0) { $0 + $1.rect.width * $1.rect.height }
        XCTAssertEqual(covered, bounds.width * bounds.height, accuracy: 0.5)

        for tile in tiles {
            XCTAssertTrue(bounds.insetBy(dx: -0.5, dy: -0.5).contains(tile.rect), "\(tile.id) escaped bounds")
        }

        for (index, tile) in tiles.enumerated() {
            for other in tiles[(index + 1)...] {
                let overlap = tile.rect.intersection(other.rect)
                XCTAssertTrue(
                    overlap.isNull || overlap.width < 0.5 || overlap.height < 0.5,
                    "\(tile.id) overlaps \(other.id)"
                )
            }
        }
    }

    func testAreaIsProportionalToWeight() throws {
        let tiles = TreemapLayout.tiles(for: [("big", 75), ("small", 25)], in: bounds)
        let areas = Dictionary(
            uniqueKeysWithValues: tiles.map { ($0.id, $0.rect.width * $0.rect.height) }
        )

        let big = try XCTUnwrap(areas["big"])
        let small = try XCTUnwrap(areas["small"])
        XCTAssertEqual(big / small, 3, accuracy: 0.05)
    }

    func testTilesStaySquarishRatherThanBecomingSlivers() {
        let weights = [("a", 40.0), ("b", 30.0), ("c", 15.0), ("d", 10.0), ("e", 5.0)]
        let tiles = TreemapLayout.tiles(for: weights, in: bounds)

        for tile in tiles {
            let ratio = max(tile.rect.width, tile.rect.height) / max(1, min(tile.rect.width, tile.rect.height))
            XCTAssertLessThan(ratio, 9, "\(tile.id) is a sliver at \(tile.rect)")
        }
    }

    func testIgnoresNonPositiveWeightsAndEmptyBounds() {
        let withZeros = TreemapLayout.tiles(for: [("a", 10), ("zero", 0), ("negative", -5)], in: bounds)
        XCTAssertEqual(withZeros.map(\.id), ["a"])

        XCTAssertTrue(TreemapLayout.tiles(for: [("a", 10)], in: .zero).isEmpty)

        let empty: [(id: String, weight: Double)] = []
        XCTAssertTrue(TreemapLayout.tiles(for: empty, in: bounds).isEmpty)
    }

    func testSingleItemFillsEverything() {
        let tiles = TreemapLayout.tiles(for: [("only", 42)], in: bounds)
        XCTAssertEqual(tiles.count, 1)
        XCTAssertEqual(tiles[0].rect.width, bounds.width, accuracy: 0.01)
        XCTAssertEqual(tiles[0].rect.height, bounds.height, accuracy: 0.01)
    }
}
