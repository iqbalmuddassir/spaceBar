import Foundation

extension CleanTargetRegistry {
    /// Fixed skips for system / shared caches that must never appear under App Caches.
    static let staticSkippedCacheNames: Set<String> = [
        "CloudKit",
        "com.apple.Safari",
        "FamilyCircle",
        "GameKit",
        "com.apple.accountsd",
        "com.apple.bird",
        "com.apple.findmy",
        "com.apple.homed",
        "CocoaPods",
        "org.swift.swiftpm",
        "Homebrew",
        "pip",
        "go-build",
        "Yarn",
        "nix",
        "bazel",
        "bazelisk"
    ]

    /// Dedicated reclaim rows under `~/Library/Caches` that are gated on folder existence.
    /// Listed here so App Caches still skips them when the dedicated target is not currently registered.
    static let knownDedicatedLibraryCachesNames: Set<String> = [
        "ollama",
        "claude-cli-nodejs"
    ]

    static func skippedCacheNames(dedicatedFolderNames: Set<String>) -> Set<String> {
        staticSkippedCacheNames
            .union(knownDedicatedLibraryCachesNames)
            .union(dedicatedFolderNames)
    }

    static func safeCacheChildren(
        of caches: URL,
        dedicatedFolderNames: Set<String> = []
    ) -> [URL] {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: caches,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let skipped = skippedCacheNames(dedicatedFolderNames: dedicatedFolderNames)
        return children.filter { url in
            let name = url.lastPathComponent
            if skipped.contains(name) {
                return false
            }
            if name.hasPrefix("com.apple.") {
                return false
            }
            return true
        }
    }

    static func uvCacheURL(home: URL) -> URL {
        let fallback = home.appendingPathComponent(".cache/uv", isDirectory: true)
        if let env = ProcessInfo.processInfo.environment["UV_CACHE_DIR"], !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            return DeletePathGuard.constrainedToolCacheURL(url, requiredPathFragment: "uv") ?? fallback
        }
        return fallback
    }

    static func detectPnpmStore() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pnpm", "store", "path"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            guard let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !path.isEmpty else { return nil }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.path),
                  let safe = DeletePathGuard.constrainedToolCacheURL(url, requiredPathFragment: "pnpm")
            else { return nil }
            return safe
        } catch {
            return nil
        }
    }

    static func dockerAvailable() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "info"]
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
}
