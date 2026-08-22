import AppKit
import SwiftUI

@MainActor
enum SnapshotExport {
    static let marketingScale: CGFloat = 3

    static func makeHostedPanel(rootView: some View, size: CGSize? = nil) -> NSView {
        let panelSize = size ?? SnapshotFixtures.panelSize
        let backdrop = NSView(frame: NSRect(origin: .zero, size: panelSize))
        backdrop.wantsLayer = true
        backdrop.layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.30, alpha: 1).cgColor

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = backdrop.bounds
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.cornerRadius = 18
        hosting.layer?.cornerCurve = .continuous
        hosting.layer?.masksToBounds = true
        backdrop.addSubview(hosting)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = true
        window.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.22, blue: 0.30, alpha: 1)
        window.isReleasedWhenClosed = false
        window.contentView = backdrop
        window.orderFront(nil)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        hosting.layoutSubtreeIfNeeded()
        return backdrop
    }

    /// Renders `view` into a bitmap at a fixed, display-independent pixel scale.
    ///
    /// `assertSnapshot(of: NSView, ...)` asks AppKit for a caching bitmap sized to the view's
    /// *window's* `backingScaleFactor`, which reflects whatever screen the test happens to run
    /// on (1x off a real display, 2x on Retina). That makes the recorded reference PNGs only
    /// reproducible on a machine with the same screen scale as whoever recorded them. Rendering
    /// into a bitmap of an explicit pixel size (as `exportHiResSnapshot` below already does for
    /// doc screenshots) sidesteps the window entirely, so the same view always produces the same
    /// pixel dimensions everywhere.
    static func renderedImage(from view: NSView, scale: CGFloat = 1) -> NSImage {
        let pixelSize = NSSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("Could not create bitmap rep for snapshot of \(view)")
        }
        rep.size = view.bounds.size
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }

    /// Same fixed-scale rendering as `renderedImage(from: NSView)`, for images built from a
    /// drawing handler (e.g. `makeMenuBarImage()`) whose `cgImage(forProposedRect:)` otherwise
    /// also renders relative to the current screen's backing scale factor.
    static func renderedImage(from sourceImage: NSImage, scale: CGFloat = 1) -> NSImage {
        let pixelSize = NSSize(width: sourceImage.size.width * scale, height: sourceImage.size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("Could not create bitmap rep for snapshot of \(sourceImage)")
        }
        rep.size = sourceImage.size

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            sourceImage.draw(
                in: NSRect(origin: .zero, size: sourceImage.size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: sourceImage.size)
        image.addRepresentation(rep)
        return image
    }

    static func exportREADMESnapshot(from view: NSView, named name: String) {
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        exportREADMESnapshot(image: image, named: name)
    }

    static func exportREADMESnapshot(image: NSImage, named name: String) {
        writePNG(image: image, directory: docsDirectory(), named: name)
    }

    static func exportHiResSnapshot(from view: NSView, named name: String) {
        let scale = marketingScale
        let pixelSize = NSSize(
            width: view.bounds.width * scale,
            height: view.bounds.height * scale
        )
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = view.bounds.size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        view.cacheDisplay(in: view.bounds, to: rep)
        NSGraphicsContext.restoreGraphicsState()

        writePNG(rep: rep, directory: hiResDocsDirectory(), named: name)
    }

    static func exportHiResSnapshot(image: NSImage, named name: String) {
        let scale = marketingScale
        let pixelSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return }
        rep.size = image.size

        NSGraphicsContext.saveGraphicsState()
        if let context = NSGraphicsContext(bitmapImageRep: rep) {
            NSGraphicsContext.current = context
            image.draw(
                in: NSRect(origin: .zero, size: image.size),
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: false,
                hints: [.interpolation: NSImageInterpolation.high]
            )
        }
        NSGraphicsContext.restoreGraphicsState()

        writePNG(rep: rep, directory: hiResDocsDirectory(), named: name)
    }

    private static func writePNG(image: NSImage, directory: URL, named name: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return }
        writePNG(rep: bitmap, directory: directory, named: name)
    }

    private static func writePNG(rep: NSBitmapImageRep, directory: URL, named name: String) {
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    private static func docsDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Docs", isDirectory: true)
    }

    private static func hiResDocsDirectory() -> URL {
        docsDirectory().appendingPathComponent("hi-res", isDirectory: true)
    }
}
