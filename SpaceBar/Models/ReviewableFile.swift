import Foundation

enum ReviewableFileKind: String, Equatable {
    case screenshot
    case recording
    case installer

    var label: String {
        switch self {
        case .screenshot: "Screenshot"
        case .recording: "Recording"
        case .installer: "Installer"
        }
    }

    var pluralLabel: String {
        switch self {
        case .screenshot: "screenshots"
        case .recording: "recordings"
        case .installer: "installers"
        }
    }
}

enum ReviewableFileCategory: String, Equatable, CaseIterable {
    case screenshotsAndRecordings
    case installerPackages

    var kinds: [ReviewableFileKind] {
        switch self {
        case .screenshotsAndRecordings: [.screenshot, .recording]
        case .installerPackages: [.installer]
        }
    }

    var title: String {
        switch self {
        case .screenshotsAndRecordings: "Screenshots & Recordings"
        case .installerPackages: "Installer Packages"
        }
    }

    var scanningStatus: String {
        switch self {
        case .screenshotsAndRecordings: "Scanning screenshots & recordings…"
        case .installerPackages: "Scanning installer packages…"
        }
    }

    var emptyStatus: String {
        switch self {
        case .screenshotsAndRecordings: "No screenshots or recordings found"
        case .installerPackages: "No installer packages found"
        }
    }

    var scanningLocationsDetail: String {
        switch self {
        case .screenshotsAndRecordings: "Scanning Desktop, Pictures, Movies…"
        case .installerPackages: "Scanning Downloads, Desktop…"
        }
    }

    var checkedLocationsDetail: String {
        switch self {
        case .screenshotsAndRecordings: "Checked Desktop, Pictures, Movies, Downloads"
        case .installerPackages: "Checked Downloads, Desktop"
        }
    }

    var emptyReclaimHint: String {
        switch self {
        case .screenshotsAndRecordings: "No media to reclaim"
        case .installerPackages: "No installers to reclaim"
        }
    }

    var symbolName: String {
        switch self {
        case .screenshotsAndRecordings: "photo.on.rectangle.angled"
        case .installerPackages: "shippingbox"
        }
    }
}

struct ReviewableFile: Identifiable, Equatable, Hashable {
    let id: URL
    let url: URL
    let kind: ReviewableFileKind
    let byteSize: UInt64
    let modified: Date

    var name: String {
        url.lastPathComponent
    }

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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
