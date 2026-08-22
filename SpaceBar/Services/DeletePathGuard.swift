import Foundation

enum DeletePathGuard {
    enum Refusal: LocalizedError {
        case outsideHome
        case forbiddenRoot
        case notAllowlisted

        var errorDescription: String? {
            switch self {
            case .outsideHome:
                "Refused to delete a path outside your home folder."
            case .forbiddenRoot:
                "Refused to delete a protected system or home root path."
            case .notAllowlisted:
                "Refused to delete a path that is not an approved cleanup location."
            }
        }
    }

    static var homePath: String {
        FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    }

    static func isUnderHome(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = homePath
        guard path != home else { return false }
        return path.hasPrefix(home + "/")
    }

    static func isForbiddenRoot(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = homePath
        let forbidden = [
            "/",
            home,
            home + "/Desktop",
            home + "/Documents",
            home + "/Downloads",
            home + "/Pictures",
            home + "/Movies",
            home + "/Music",
            "/System",
            "/Library",
            "/Applications",
            "/Users"
        ]
        return forbidden.contains(path)
    }

    /// Home-relative suffixes for approved cleanup locations, joined with `homePath` at check time.
    private static let allowlistedPathSuffixes = [
        "/Library/Caches",
        "/Library/Developer/Xcode/DerivedData",
        "/Library/Developer/Xcode/Archives",
        "/Library/Developer/Xcode/iOS DeviceSupport",
        "/.android/avd",
        "/.gradle/caches",
        "/.npm/_cacache",
        "/.cache/uv",
        "/Library/Caches/CocoaPods",
        "/Library/Caches/org.swift.swiftpm",
        "/Library/Caches/Homebrew",
        "/Library/Caches/pip",
        "/.Trash",
        "/Library/Application Support/Claude/Cache",
        "/Library/Application Support/Claude/Code Cache",
        "/Library/Application Support/Claude/GPUCache",
        "/Library/Application Support/Claude/DawnWebGPUCache",
        "/Library/Application Support/Claude/DawnGraphiteCache",
        "/Library/Application Support/Cursor/Cache",
        "/Library/Application Support/Cursor/Code Cache",
        "/Library/Application Support/Cursor/GPUCache",
        "/Library/Application Support/Cursor/DawnGraphiteCache",
        "/Library/Application Support/Cursor/DawnWebGPUCache",
        "/Library/Application Support/Cursor/CachedData",
        "/Library/Application Support/Cursor/CachedExtensionVSIXs",
        "/Library/Application Support/Cursor/CachedProfilesData",
        "/Library/Application Support/Cursor/CachedConfigurations",
        "/Library/Application Support/Windsurf/Cache",
        "/Library/Application Support/Windsurf/Code Cache",
        "/Library/Application Support/Windsurf/GPUCache",
        "/Library/Application Support/Windsurf/CachedData",
        "/Library/Application Support/Windsurf/CachedExtensionVSIXs",
        "/.continue/cache",
        "/.codex/cache",
        "/.cargo/registry",
        "/go/pkg/mod",
        "/.bun/install/cache",
        "/.node-gyp",
        "/Library/Caches/nix",
        "/Library/Caches/bazel",
        "/Library/Caches/bazelisk",
        "/Library/Application Support/Code/Cache",
        "/Library/Application Support/Code/Code Cache",
        "/Library/Application Support/Code/GPUCache",
        "/Library/Application Support/Code/CachedData",
        "/Library/Application Support/Code/CachedExtensionVSIXs"
    ]

    /// Free-floating fragments allowed anywhere under home, for tools whose cache dir can be
    /// fully relocated by the user (pnpm's `store-dir`, Bazelisk's `BAZELISK_HOME`).
    private static let allowlistedPathFragments = ["pnpm", "bazelisk"]

    static func isAllowlistedCleanupPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = homePath
        let prefixes = allowlistedPathSuffixes.map { home + $0 }
        if prefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
        if path == tmp || path.hasPrefix(tmp.hasSuffix("/") ? tmp : tmp + "/") {
            return true
        }
        if path.hasPrefix(home + "/") {
            let lowered = path.lowercased()
            return allowlistedPathFragments.contains { lowered.contains($0) }
        }
        return false
    }

    static func validateForCleanupDelete(_ url: URL) throws {
        if isForbiddenRoot(url) {
            throw Refusal.forbiddenRoot
        }
        guard isUnderHome(url) || isTempChild(url) else {
            throw Refusal.outsideHome
        }
        guard isAllowlistedCleanupPath(url) else {
            throw Refusal.notAllowlisted
        }
    }

    static func validateForReviewableFileDelete(_ url: URL) throws {
        if isForbiddenRoot(url) {
            throw Refusal.forbiddenRoot
        }
        guard isUnderHome(url) else {
            throw Refusal.outsideHome
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue else {
            throw Refusal.notAllowlisted
        }
    }

    static func validateForBuildArtifactDelete(_ url: URL) throws {
        if isForbiddenRoot(url) {
            throw Refusal.forbiddenRoot
        }
        guard isUnderHome(url) else {
            throw Refusal.outsideHome
        }

        let standardized = url.standardizedFileURL
        let path = standardized.path
        guard !path.hasPrefix(homePath + "/Library/") else {
            throw Refusal.notAllowlisted
        }
        guard BuildArtifactRule.knownDirectoryNames.contains(standardized.lastPathComponent.lowercased()) else {
            throw Refusal.notAllowlisted
        }
        // An artifact sits inside a project folder, never straight in home.
        let depthBelowHome = path.dropFirst(homePath.count).split(separator: "/").count
        guard depthBelowHome >= 2 else {
            throw Refusal.notAllowlisted
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw Refusal.notAllowlisted
        }
        let isSymlink = (try? standardized.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink
        guard isSymlink != true else {
            throw Refusal.notAllowlisted
        }
    }

    static func constrainedToolCacheURL(_ url: URL, requiredPathFragment: String?) -> URL? {
        let standardized = url.standardizedFileURL
        guard isUnderHome(standardized), !isForbiddenRoot(standardized) else { return nil }
        guard let fragment = requiredPathFragment?.lowercased() else { return standardized }
        guard standardized.path.lowercased().contains(fragment) else { return nil }
        return standardized
    }

    private static func isTempChild(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
        let prefix = tmp.hasSuffix("/") ? tmp : tmp + "/"
        return path == tmp || path.hasPrefix(prefix)
    }
}
