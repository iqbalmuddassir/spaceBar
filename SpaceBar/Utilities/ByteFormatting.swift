import Foundation

enum ByteFormatting {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    private static let gb = 1_000_000_000.0
    private static let mb = 1_000_000.0
    private static let kb = 1000.0

    static func string(from bytes: UInt64) -> String {
        formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    static func compactFreeSpace(from bytes: UInt64) -> String {
        let value = Double(bytes)
        let asGB = value / gb
        if asGB >= 99.95 {
            return String(format: "%.0f GB", asGB)
        }
        if asGB >= 9.995 {
            return String(format: "%.1f GB", asGB)
        }
        if asGB >= 0.995 {
            return String(format: "%.2f GB", asGB)
        }
        let asMB = value / mb
        if asMB >= 0.5 {
            return String(format: "%.0f MB", asMB)
        }
        let asKB = value / kb
        if asKB >= 0.5 {
            return String(format: "%.0f KB", asKB)
        }
        return "\(bytes) B"
    }
}
