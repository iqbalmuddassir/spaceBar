import AppKit
import SwiftUI

extension DiskSpaceMonitor {
    func makeMenuBarImage() -> NSImage {
        let label = freeSpaceLabel as NSString
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let textSize = label.size(withAttributes: [.font: font])

        let horizontalPadding: CGFloat = 8
        let minWidth: CGFloat = 64
        let height: CGFloat = 16
        let width = max(minWidth, ceil(textSize.width) + horizontalPadding * 2)
        let size = NSSize(width: width, height: height)

        let fillColor = level.nsColor
        let fraction = CGFloat(freeFraction)

        let image = NSImage(size: size, flipped: false) { _ in
            let barRect = NSRect(x: 0, y: 0, width: width, height: height)
            let radius = height / 2

            NSColor.labelColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()

            let fillWidth = max(height, width * fraction)
            let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: height)
            fillColor.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()

            let textColor = Self.contrastingLabelColor(on: fillColor, fillCoversCenter: fraction > 0.45)
            let textOrigin = NSPoint(
                x: (width - textSize.width) / 2,
                y: (height - textSize.height) / 2 - 0.5
            )
            label.draw(
                at: textOrigin,
                withAttributes: [
                    .font: font,
                    .foregroundColor: textColor
                ]
            )
            return true
        }

        image.isTemplate = false
        return image
    }

    private static func contrastingLabelColor(on fill: NSColor, fillCoversCenter: Bool) -> NSColor {
        if fillCoversCenter {
            return .white
        }
        return NSColor.labelColor
    }
}

extension DiskSpaceLevel {
    var nsColor: NSColor {
        switch self {
        case .healthy: NSColor.systemGreen
        case .warning: NSColor.systemOrange
        case .critical: NSColor.systemRed
        }
    }
}
