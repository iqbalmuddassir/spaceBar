import AppKit
import SwiftUI

extension DiskSpaceMonitor {
    func makeMenuBarImage() -> NSImage {
        let label = (settings.showPercentageInPill ? freePercentLabel : freeSpaceLabel) as NSString
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let textSize = label.size(withAttributes: [.font: font])

        let horizontalPadding: CGFloat = 8
        let minWidth: CGFloat = settings.showPercentageInPill ? 44 : 64
        let height: CGFloat = 16
        let width = max(minWidth, ceil(textSize.width) + horizontalPadding * 2)
        let size = NSSize(width: width, height: height)

        let accent = level.nsColor
        // "Full color only when critical" keeps the bar calm until it matters: everything below
        // critical draws as a tinted capsule instead of a solid block of colour.
        let isSolid = settings.pillStyle == .solid
            && (level == .critical || !settings.fullColorOnlyWhenCritical)
        let fraction = CGFloat(freeFraction)

        let image = NSImage(size: size, flipped: false) { _ in
            let barRect = NSRect(x: 0, y: 0, width: width, height: height)
            let radius = height / 2

            NSColor.labelColor.withAlphaComponent(0.14).setFill()
            NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()

            if isSolid {
                let fillWidth = max(height, width * fraction)
                let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: height)
                accent.setFill()
                NSBezierPath(roundedRect: fillRect, xRadius: radius, yRadius: radius).fill()
            } else {
                accent.withAlphaComponent(0.20).setFill()
                NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()
            }

            let textColor = Self.labelColor(on: accent, solid: isSolid, fillCoversCenter: fraction > 0.45)
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

    private static func labelColor(on fill: NSColor, solid: Bool, fillCoversCenter: Bool) -> NSColor {
        guard solid else { return fill }
        return fillCoversCenter ? .white : NSColor.labelColor
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
