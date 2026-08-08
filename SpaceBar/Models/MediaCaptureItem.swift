import Foundation

enum MediaCaptureKind: String, Equatable {
    case screenshot
    case recording

    var label: String {
        switch self {
        case .screenshot: return "Screenshot"
        case .recording: return "Recording"
        }
    }
}

struct MediaCaptureItem: Identifiable, Equatable, Hashable {
    let id: URL
    let url: URL
    let kind: MediaCaptureKind
    let byteSize: UInt64
    let modified: Date

    var name: String { url.lastPathComponent }

    var sizeLabel: String {
        ByteFormatting.string(from: byteSize)
    }

    var dateLabel: String {
        Self.dateFormatter.string(from: modified)
    }

    var relativeAgeLabel: String {
        StaleAgeCalculator.relativeAge(from: modified)
            .replacingOccurrences(of: "last modified ", with: "")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}
