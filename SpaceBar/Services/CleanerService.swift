import AppKit
import Foundation

enum CleanerError: LocalizedError {
    case permissionDenied
    case commandFailed(String)
    case unknown(String)
    case nothingDeleted(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied. Grant Full Disk Access to SpaceBar in System Settings."
        case .commandFailed(let message):
            return message
        case .unknown(let message):
            return message
        case .nothingDeleted(let message):
            return message
        }
    }

    var isPermissionRelated: Bool {
        if case .permissionDenied = self { return true }
        return false
    }
}

struct CleanResult: Sendable {
    let bytesBefore: UInt64
    let bytesAfter: UInt64
    let deletedEntries: Int
    let failedEntries: Int

    var bytesFreed: UInt64 { bytesBefore > bytesAfter ? bytesBefore - bytesAfter : 0 }
}

enum CleanerService {
    static func clean(_ target: CleanTarget) throws -> CleanResult {
        switch target.strategy {
        case .deletePaths(let urls):
            return try deleteContents(of: urls)
        case .emptyTrash:
            let before = TrashService.info().byteSize
            try TrashService.empty()
            let after = TrashService.info().byteSize
            return CleanResult(bytesBefore: before, bytesAfter: after, deletedEntries: 1, failedEntries: 0)
        case .simctlDeleteUnavailable:
            let before = estimateOrZero(target)
            try run(executable: "/usr/bin/xcrun", arguments: ["simctl", "delete", "unavailable"])
            return CleanResult(bytesBefore: before, bytesAfter: 0, deletedEntries: 1, failedEntries: 0)
        case .dockerBuilderPrune:
            let before = estimateOrZero(target)
            try run(executable: "/usr/bin/env", arguments: ["docker", "builder", "prune", "-f"])
            return CleanResult(bytesBefore: before, bytesAfter: 0, deletedEntries: 1, failedEntries: 0)
        }
    }

    private static func estimateOrZero(_ target: CleanTarget) -> UInt64 {
        switch target.strategy {
        case .deletePaths(let urls):
            return DirectorySizer.size(of: urls)
        default:
            return 0
        }
    }

    static func hasFullDiskAccess() -> Bool {
        let probes = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
        ]
        for url in probes {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
                return true
            } catch {
                continue
            }
        }
        return false
    }

    static func openFullDiskAccessSettings() {
        revealInFullDiskAccessList()
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for url in urls where shellOpen(url) {
            activateSystemSettings()
            return
        }
        _ = shellOpen("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        activateSystemSettings()
    }

    private static func revealInFullDiskAccessList() {
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari/Bookmarks.plist"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
        ]
        for url in candidates {
            _ = try? Data(contentsOf: url, options: [.mappedIfSafe])
            _ = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        }
    }

    @discardableResult
    private static func shellOpen(_ urlString: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func activateSystemSettings() {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
            configuration: config
        ) { _, _ in }
    }

    private static func deleteContents(of urls: [URL]) throws -> CleanResult {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        let before = DirectorySizer.size(of: existing)

        var deleted = 0
        var failed = 0
        var permissionFails = 0
        var lastError: String?

        for url in existing {
            let items = expansionTargets(for: url)
            if items.isEmpty {
                // Directory existed but listing failed — treat as permission/access issue.
                failed += 1
                permissionFails += 1
                lastError = "Could not list \(url.lastPathComponent)"
                continue
            }
            for item in items {
                if forceRemove(item) {
                    deleted += 1
                } else {
                    failed += 1
                    lastError = item.lastPathComponent
                    if !FileManager.default.isWritableFile(atPath: item.path)
                        || !hasFullDiskAccess() && item.path.contains("/Library/") {
                        permissionFails += 1
                    }
                }
            }
        }

        let after = DirectorySizer.size(of: urls.filter { FileManager.default.fileExists(atPath: $0.path) })
        let result = CleanResult(bytesBefore: before, bytesAfter: after, deletedEntries: deleted, failedEntries: failed)

        if deleted == 0 {
            if permissionFails > 0 && !hasFullDiskAccess() {
                throw CleanerError.permissionDenied
            }
            throw CleanerError.nothingDeleted(lastError.map { "Could not delete \($0)" } ?? "Nothing was deleted.")
        }

        // If we deleted entries but measured size barely moved and everything still exists, call it out.
        if result.bytesFreed == 0 && failed > deleted {
            throw CleanerError.nothingDeleted("Files are locked or protected. Quit related apps and try again.")
        }

        return result
    }

    private static func expansionTargets(for url: URL) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }

        if isDir.boolValue && shouldDeleteChildren(of: url) {
            do {
                return try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            } catch {
                return []
            }
        }
        return [url]
    }

    /// Prefer `rm -rf` — more reliable than FileManager for large/stubborn trees.
    private static func forceRemove(_ url: URL) -> Bool {
        // Try FileManager first (fast path)
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            // Fall through to rm
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/rm")
        process.arguments = ["-rf", url.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return !FileManager.default.fileExists(atPath: url.path)
            }
        } catch {
            return false
        }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    private static func shouldDeleteChildren(of url: URL) -> Bool {
        let path = normalized(url.path)
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = [
            normalized(NSTemporaryDirectory()),
            normalized("\(home)/Library/Caches"),
            normalized("\(home)/Library/Developer/Xcode/DerivedData"),
            normalized("\(home)/Library/Developer/Xcode/Archives"),
            normalized("\(home)/Library/Developer/Xcode/iOS DeviceSupport"),
            normalized("\(home)/.android/avd"),
            normalized("\(home)/.gradle/caches")
        ]
        return roots.contains(path)
    }

    private static func normalized(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func run(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let err = Pipe()
        process.standardOutput = Pipe()
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CleanerError.commandFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw CleanerError.commandFailed(message?.isEmpty == false ? message! : "Command failed (\(process.terminationStatus))")
        }
    }
}
