import Foundation

extension CleanTargetRegistry {
    static let skippedCacheNames: Set<String> = [
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
        "bazel"
    ]

    static func safeCacheChildren(of caches: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: caches,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return children.filter { url in
            let name = url.lastPathComponent
            if skippedCacheNames.contains(name) {
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
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
}
