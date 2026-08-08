import AppKit
import Combine
import Foundation
import SwiftUI

enum DiskSpaceLevel: Equatable {
    case healthy
    case warning
    case critical

    var color: Color {
        switch self {
        case .healthy: .green
        case .warning: .orange
        case .critical: .red
        }
    }

    var label: String {
        switch self {
        case .healthy: "Plenty of space"
        case .warning: "Running low"
        case .critical: "Critically low"
        }
    }
}

@MainActor
final class DiskSpaceMonitor: ObservableObject {
    @Published private(set) var freeBytes: UInt64 = 0
    @Published private(set) var totalBytes: UInt64 = 0
    @Published private(set) var freeSpaceLabel: String = "…"
    @Published private(set) var freePercentLabel: String = "…"
    @Published private(set) var freeFraction: Double = 1
    @Published private(set) var level: DiskSpaceLevel = .healthy
    @Published private(set) var menuBarImage: NSImage = .init(size: NSSize(width: 1, height: 1))

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMenuBarImage()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        let stats = Self.volumeStats(at: "/")
        apply(stats: stats)
    }

    func refreshAfterCleaning() async {
        refresh()
        try? await Task.sleep(nanoseconds: 800_000_000)
        refresh()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        refresh()
    }

    private func apply(stats: (free: UInt64, total: UInt64)) {
        freeBytes = stats.free
        totalBytes = stats.total
        freeSpaceLabel = ByteFormatting.compactFreeSpace(from: freeBytes)

        let fraction = stats.total > 0 ? Double(stats.free) / Double(stats.total) : 1
        freeFraction = min(max(fraction, 0), 1)
        freePercentLabel = String(format: "%.0f%%", freeFraction * 100)

        if freeFraction < 0.10 {
            level = .critical
        } else if freeFraction < 0.50 {
            level = .warning
        } else {
            level = .healthy
        }

        refreshMenuBarImage()
        objectWillChange.send()
    }

    func refreshMenuBarImage() {
        menuBarImage = makeMenuBarImage()
    }

    nonisolated static func volumeStats(at path: String) -> (free: UInt64, total: UInt64) {
        let url = URL(fileURLWithPath: path)
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey,
            .volumeTotalCapacityKey
        ]
        if let values = try? url.resourceValues(forKeys: keys) {
            let total = values.volumeTotalCapacity.map { UInt64(max(0, $0)) } ?? 0
            let freeImportant = values.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }
            let freeBasic = values.volumeAvailableCapacity.map { UInt64(max(0, $0)) }
            if let free = freeImportant ?? freeBasic, total > 0 {
                return (free, total)
            }
        }

        var stat = statfs()
        guard statfs(path, &stat) == 0 else { return (0, 0) }
        let blockSize = UInt64(stat.f_bsize)
        let free = UInt64(stat.f_bavail) * blockSize
        let total = UInt64(stat.f_blocks) * blockSize
        return (free, total)
    }
}
