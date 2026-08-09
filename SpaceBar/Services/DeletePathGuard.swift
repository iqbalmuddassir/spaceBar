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

    static func isAllowlistedCleanupPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let home = homePath
        let prefixes = [
            home + "/Library/Caches",
            home + "/Library/Developer/Xcode/DerivedData",
            home + "/Library/Developer/Xcode/Archives",
            home + "/Library/Developer/Xcode/iOS DeviceSupport",
            home + "/.android/avd",
            home + "/.gradle/caches",
            home + "/.npm/_cacache",
            home + "/.cache/uv",
            home + "/Library/Caches/CocoaPods",
            home + "/Library/Caches/org.swift.swiftpm",
            home + "/Library/Caches/Homebrew",
            home + "/Library/Caches/pip",
            home + "/.Trash"
        ]
        if prefixes.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.path
        if path == tmp || path.hasPrefix(tmp.hasSuffix("/") ? tmp : tmp + "/") {
            return true
        }
        if path.hasPrefix(home + "/"), path.lowercased().contains("pnpm") {
            return true
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
