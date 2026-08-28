import AppKit
import Foundation

enum CleanerError: LocalizedError {
    case permissionDenied
    case automationDenied
    case commandFailed(String)
    case unknown(String)
    case nothingDeleted(String)
    case unsafePath(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Permission denied. Grant Full Disk Access to SpaceBar in System Settings."
        case .automationDenied:
            "Finder Automation is required to empty Trash. Enable SpaceBar under Privacy & Security → Automation."
        case let .commandFailed(message):
            message
        case let .unknown(message):
            message
        case let .nothingDeleted(message):
            message
        case let .unsafePath(message):
            message
        }
    }

    var isPermissionRelated: Bool {
        if case .permissionDenied = self {
            return true
        }
        return false
    }

    var isAutomationRelated: Bool {
        if case .automationDenied = self {
            return true
        }
        return false
    }
}

struct CleanResult: Sendable {
    let bytesBefore: UInt64
    let bytesAfter: UInt64
    let deletedEntries: Int
    let failedEntries: Int
    let failedPaths: [String]

    init(bytesBefore: UInt64, bytesAfter: UInt64, deletedEntries: Int, failedEntries: Int, failedPaths: [String] = []) {
        self.bytesBefore = bytesBefore
        self.bytesAfter = bytesAfter
        self.deletedEntries = deletedEntries
        self.failedEntries = failedEntries
        self.failedPaths = failedPaths
    }

    var bytesFreed: UInt64 {
        bytesBefore > bytesAfter ? bytesBefore - bytesAfter : 0
    }
}

enum CleanerService {
    static func clean(_ target: CleanTarget) throws -> CleanResult {
        switch target.strategy {
        case let .deletePaths(urls):
            return try deleteContents(of: urls)
        case .emptyTrash:
            let before = TrashService.info().byteSize
            try TrashService.empty()
            let after = TrashService.info().byteSize
            return CleanResult(bytesBefore: before, bytesAfter: after, deletedEntries: 1, failedEntries: 0)
        case .simctlDeleteUnavailable:
            return try commandDrivenClean(
                measure: CommandSizeEstimator.simulatorUnavailableSize,
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "delete", "unavailable"]
            )
        case .dockerBuilderPrune:
            return try commandDrivenClean(
                measure: CommandSizeEstimator.dockerBuildCacheSize,
                executable: "/usr/bin/env",
                arguments: ["docker", "builder", "prune", "-f"]
            )
        case .dockerSystemPrune:
            return try commandDrivenClean(
                measure: CommandSizeEstimator.dockerReclaimableSize,
                executable: "/usr/bin/env",
                arguments: ["docker", "system", "prune", "-af", "--volumes"]
            )
        case .simctlDeleteUnusedRuntimes:
            return try deleteUnusedSimulatorRuntimes()
        case .timeMachineThinLocalSnapshots:
            return try commandDrivenClean(
                measure: CommandSizeEstimator.timeMachineLocalSnapshotSize,
                executable: "/usr/bin/tmutil",
                arguments: ["thinlocalsnapshots", "/", "999999999999", "4"]
            )
        }
    }

    /// Shared shape for strategies that run a command and measure reclaimed space before/after.
    private static func commandDrivenClean(
        measure: () -> UInt64,
        executable: String,
        arguments: [String]
    ) throws -> CleanResult {
        let before = measure()
        try run(executable: executable, arguments: arguments)
        let after = measure()
        return CleanResult(bytesBefore: before, bytesAfter: after, deletedEntries: 1, failedEntries: 0)
    }

    /// Deletes each stale runtime by identifier (see `unusedSimulatorRuntimes`) rather than via
    /// `--notUsedSinceDays`.
    private static func deleteUnusedSimulatorRuntimes() throws -> CleanResult {
        let runtimes = CommandSizeEstimator.unusedSimulatorRuntimes()
        guard !runtimes.isEmpty else {
            throw CleanerError.nothingDeleted("No unused simulator runtimes to remove.")
        }
        let before = runtimes.reduce(0) { $0 + $1.sizeBytes }
        var deleted = 0
        var failedVersions: [String] = []
        for runtime in runtimes {
            do {
                try run(executable: "/usr/bin/xcrun", arguments: ["simctl", "runtime", "delete", runtime.id])
                deleted += 1
            } catch {
                failedVersions.append(runtime.version)
            }
        }
        guard deleted > 0 else {
            throw CleanerError.commandFailed("Could not delete any unused simulator runtimes.")
        }
        let after = CommandSizeEstimator.simulatorUnusedRuntimeSize()
        return CleanResult(
            bytesBefore: before,
            bytesAfter: after,
            deletedEntries: deleted,
            failedEntries: failedVersions.count,
            failedPaths: failedVersions
        )
    }

    private enum ItemOutcome {
        case deleted
        case failedValidation(name: String, message: String)
        case failedRemove(name: String, likelyFDA: Bool)
        case failedListing(name: String)
    }

    private static func deleteContents(of urls: [URL]) throws -> CleanResult {
        for url in urls {
            do {
                try DeletePathGuard.validateForCleanupDelete(url)
            } catch let refusal as DeletePathGuard.Refusal {
                throw CleanerError.unsafePath(refusal.errorDescription ?? "Unsafe path")
            }
        }

        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        let before = DirectorySizer.size(of: existing)

        let tally = tally(deleteExpanded(existing))

        let after = DirectorySizer.size(of: urls.filter { FileManager.default.fileExists(atPath: $0.path) })
        let result = CleanResult(
            bytesBefore: before,
            bytesAfter: after,
            deletedEntries: tally.deleted,
            failedEntries: tally.failed,
            failedPaths: tally.failedPaths
        )

        if tally.deleted == 0 {
            if tally.permissionFails > 0, !hasFullDiskAccess() {
                throw CleanerError.permissionDenied
            }
            let message = tally.lastError.map { "Could not delete \($0)" } ?? "Nothing was deleted."
            throw CleanerError.nothingDeleted(message)
        }

        if result.bytesFreed == 0, tally.failed >= tally.deleted {
            throw CleanerError.nothingDeleted("Files are locked or protected. Quit related apps and try again.")
        }

        return result
    }

    /// App Caches expands to one item per app cache folder — deleting ~100 of those one at a
    /// time is what makes a large cache read as hung, so items are removed concurrently instead.
    private static func deleteExpanded(_ existing: [URL]) -> [ItemOutcome] {
        var expanded: [URL] = []
        var listingFailures: [ItemOutcome] = []
        for url in existing {
            let items = expansionTargets(for: url)
            if items.isEmpty {
                listingFailures.append(.failedListing(name: url.lastPathComponent))
            } else {
                expanded.append(contentsOf: items)
            }
        }

        var outcomes = [ItemOutcome](repeating: .deleted, count: expanded.count)
        outcomes.withUnsafeMutableBufferPointer { buffer in
            DispatchQueue.concurrentPerform(iterations: expanded.count) { index in
                buffer[index] = deleteOne(expanded[index])
            }
        }
        return listingFailures + outcomes
    }

    private static func deleteOne(_ item: URL) -> ItemOutcome {
        do {
            try DeletePathGuard.validateForCleanupDelete(item)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .failedValidation(name: item.lastPathComponent, message: message)
        }
        if forceRemove(item) {
            return .deleted
        }
        let lacksWrite = !FileManager.default.isWritableFile(atPath: item.path)
        let likelyFDA = !hasFullDiskAccess() && item.path.contains("/Library/")
        return .failedRemove(name: item.lastPathComponent, likelyFDA: lacksWrite || likelyFDA)
    }

    private struct Tally {
        var deleted = 0
        var failed = 0
        var permissionFails = 0
        var lastError: String?
        var failedPaths: [String] = []
    }

    private static func tally(_ outcomes: [ItemOutcome]) -> Tally {
        var tally = Tally()

        for outcome in outcomes {
            switch outcome {
            case .deleted:
                tally.deleted += 1
            case let .failedValidation(name, message):
                tally.failed += 1
                tally.failedPaths.append(name)
                tally.lastError = message
            case let .failedRemove(name, likelyFDA):
                tally.failed += 1
                tally.failedPaths.append(name)
                tally.lastError = name
                if likelyFDA {
                    tally.permissionFails += 1
                }
            case let .failedListing(name):
                tally.failed += 1
                tally.permissionFails += 1
                tally.failedPaths.append(name)
                tally.lastError = "Could not list \(name)"
            }
        }
        return tally
    }

    private static func expansionTargets(for url: URL) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }

        let isSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
        if isDir.boolValue, !isSymlink, shouldDeleteChildren(of: url) {
            do {
                return try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            } catch {
                return []
            }
        }
        return [url]
    }

    private static func forceRemove(_ url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch { }

        if runProcess("/bin/rm", ["-rf", url.path]), !FileManager.default.fileExists(atPath: url.path) {
            return true
        }

        // Some caches (e.g. Go's module cache) mark nested files/directories
        // read-only to prevent accidental edits, which blocks a plain rm -rf.
        // Make the tree writable first, then retry.
        _ = runProcess("/bin/chmod", ["-R", "u+w", url.path])
        _ = runProcess("/bin/rm", ["-rf", url.path])
        return !FileManager.default.fileExists(atPath: url.path)
    }

    @discardableResult
    private static func runProcess(_ executablePath: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
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
        process.standardOutput = FileHandle.nullDevice
        process.standardError = err
        do {
            try process.run()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let message = String(data: errData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                throw CleanerError
                    .commandFailed(message?
                        .isEmpty == false ? message! : "Command failed (\(process.terminationStatus))")
            }
        } catch {
            throw CleanerError.commandFailed(error.localizedDescription)
        }
    }
}
