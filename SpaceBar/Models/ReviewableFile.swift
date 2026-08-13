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

    /// Build artifacts carry the tool's own name in ``ReviewableFile/detailLabel`` ("Node
    /// dependencies"); this is the fallback when a row has none.
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

    /// Folders are removed recursively and are re-created by a tool, so they take a different
    /// delete guard from the single files the other kinds point at.
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

    /// What the confirmation adds under the byte count. Media and installers are gone for good;
    /// build folders are gone until the next build.
    var deleteReassurance: String {
        switch self {
        case .screenshotsAndRecordings, .installerPackages:
            "This cannot be undone."
        case .projectBuildFiles:
            "This cannot be undone, but each folder is put back by its own tool."
        }
    }

    /// Shares the cleanup targets' exclusion list, so one Settings section switches off any scan.
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
    /// Folder names like `build` and `node_modules` repeat across every project, so a build
    /// artifact row leads with the project that owns it.
    var projectName: String?
    /// What the tool calls this folder — "Node dependencies" rather than the kind's generic label.
    var detailLabel: String?
    /// What puts the folder back, shown so the choice to delete is an informed one.
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
