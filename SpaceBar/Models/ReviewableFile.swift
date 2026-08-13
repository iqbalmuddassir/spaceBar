import Foundation

enum ReviewableSortOrder: String, CaseIterable, Identifiable {
    case largest
    case newest
    case name

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .largest: "Largest"
        case .newest: "Newest"
        case .name: "Name"
        }
    }

    func areInIncreasingOrder(_ lhs: ReviewableFile, _ rhs: ReviewableFile) -> Bool {
        switch self {
        case .largest: lhs.byteSize > rhs.byteSize
        case .newest: lhs.modified > rhs.modified
        case .name: lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}

enum ReviewableFileKind: String, Equatable, Identifiable {
    case screenshot
    case recording
    case installer
    case buildArtifact

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .screenshot: "Screenshot"
        case .recording: "Recording"
        case .installer: "Installer"
        case .buildArtifact: "Build folder"
        }
    }

    var pluralLabel: String {
        switch self {
        case .screenshot: "screenshots"
        case .recording: "recordings"
        case .installer: "installers"
        case .buildArtifact: "build folders"
        }
    }

    var isDirectory: Bool {
        self == .buildArtifact
    }
}

enum ReviewableFileCategory: String, Equatable, CaseIterable {
    case screenshotsAndRecordings
    case installerPackages
    case projectBuildFiles

    var kinds: [ReviewableFileKind] {
        switch self {
        case .screenshotsAndRecordings: [.screenshot, .recording]
        case .installerPackages: [.installer]
        case .projectBuildFiles: [.buildArtifact]
        }
    }

    var title: String {
        switch self {
        case .screenshotsAndRecordings: "Screenshots & Recordings"
        case .installerPackages: "Installer Packages"
        case .projectBuildFiles: "Project Build Files"
        }
    }

    var scanningStatus: String {
        switch self {
        case .screenshotsAndRecordings: "Scanning screenshots & recordings…"
        case .installerPackages: "Scanning installer packages…"
        case .projectBuildFiles: "Scanning projects for build files…"
        }
    }

    var emptyStatus: String {
        switch self {
        case .screenshotsAndRecordings: "No screenshots or recordings found"
        case .installerPackages: "No installer packages found"
        case .projectBuildFiles: "No project build files found"
        }
    }

    var scanningLocationsDetail: String {
        switch self {
        case .screenshotsAndRecordings: "Scanning Desktop, Pictures, Movies…"
        case .installerPackages: "Scanning Downloads, Desktop…"
        case .projectBuildFiles: "Walking your project folders…"
        }
    }

    var checkedLocationsDetail: String {
        switch self {
        case .screenshotsAndRecordings: "Checked Desktop, Pictures, Movies, Downloads"
        case .installerPackages: "Checked Downloads, Desktop"
        case .projectBuildFiles: "Checked your home folder for projects, ignoring anything under 10 MB"
        }
    }

    var emptyReclaimHint: String {
        switch self {
        case .screenshotsAndRecordings: "No media to reclaim"
        case .installerPackages: "No installers to reclaim"
        case .projectBuildFiles: "No build files to reclaim"
        }
    }

    var symbolName: String {
        switch self {
        case .screenshotsAndRecordings: "photo.on.rectangle.angled"
        case .installerPackages: "shippingbox"
        case .projectBuildFiles: "hammer"
        }
    }

    var deleteReassurance: String {
        switch self {
        case .screenshotsAndRecordings, .installerPackages:
            "This cannot be undone."
        case .projectBuildFiles:
            "This cannot be undone, but each folder is put back by its own tool."
        }
    }

    /// Namespaced because it shares `excludedTargetIDs` with the cleanup targets.
    var settingsID: String {
        "review-\(rawValue)"
    }
}

struct ReviewableFile: Identifiable, Equatable, Hashable {
    let id: URL
    let url: URL
    let kind: ReviewableFileKind
    let byteSize: UInt64
    let modified: Date
    var projectName: String?
    var detailLabel: String?
    var regenerationNote: String?

    var name: String {
        url.lastPathComponent
    }

    var displayName: String {
        guard let projectName else { return name }
        return "\(projectName) / \(name)"
    }

    var subtitleLabel: String {
        detailLabel ?? kind.label
    }

    var locationLabel: String? {
        guard projectName != nil else { return nil }
        return (url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
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
