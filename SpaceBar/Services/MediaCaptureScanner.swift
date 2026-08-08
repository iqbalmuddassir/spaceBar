import Foundation

enum MediaCaptureScanner {
    static func scan() -> [MediaCaptureItem] {
        let urls = candidateFiles()
        var items: [MediaCaptureItem] = []
        items.reserveCapacity(urls.count)

        for url in urls {
            if Task.isCancelled {
                break
            }
            guard let kind = classify(url) else { continue }
            let values = try? url.resourceValues(forKeys: [
                .fileSizeKey,
                .totalFileAllocatedSizeKey,
                .contentModificationDateKey,
                .isRegularFileKey
            ])
            guard values?.isRegularFile == true else { continue }
            let size = UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
            guard size > 0 else { continue }
            let modified = values?.contentModificationDate ?? .distantPast
            items.append(
                MediaCaptureItem(
                    id: url,
                    url: url,
                    kind: kind,
                    byteSize: size,
                    modified: modified
                )
            )
        }

        return items.sorted { $0.modified > $1.modified }
    }

    static func searchDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var dirs: [URL] = [
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Pictures", isDirectory: true),
            home.appendingPathComponent("Pictures/Screenshots", isDirectory: true),
            home.appendingPathComponent("Movies", isDirectory: true),
            home.appendingPathComponent("Downloads", isDirectory: true)
        ]

        if let custom = screencaptureLocation(), DeletePathGuard.isUnderHome(custom) {
            dirs.append(custom)
        }

        var seen = Set<String>()
        return dirs.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return FileManager.default.fileExists(atPath: path)
        }
    }

    private static func screencaptureLocation() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.screencapture", "location"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let path = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty else { return nil }
            let expanded = (path as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        } catch {
            return nil
        }
    }

    private static func candidateFiles() -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []

        for dir in searchDirectories() {
            guard let enumerator = fm.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            let maxDepth = depthLimit(for: dir)
            let rootPath = dir.standardizedFileURL.path

            for case let fileURL as URL in enumerator {
                if Task.isCancelled {
                    return results
                }

                let standardized = fileURL.standardizedFileURL
                let path = standardized.path
                guard path == rootPath || path.hasPrefix(rootPath + "/") else {
                    enumerator.skipDescendants()
                    continue
                }

                let depth = path.replacingOccurrences(of: rootPath, with: "")
                    .split(separator: "/")
                    .count
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }
                if classify(standardized) != nil {
                    results.append(standardized)
                }
            }
        }
        return results
    }

    private static func depthLimit(for dir: URL) -> Int {
        let name = dir.lastPathComponent.lowercased()
        if name == "pictures" || name == "movies" || name == "screenshots" {
            return 2
        }
        return 1
    }

    private static func classify(_ url: URL) -> MediaCaptureKind? {
        let name = url.lastPathComponent
        let lower = name.lowercased()
        let ext = url.pathExtension.lowercased()

        let recordingExts: Set = ["mov", "mp4", "m4v"]
        let imageExts: Set = ["png", "jpg", "jpeg", "heic"]

        if lower.hasPrefix("screen recording"), recordingExts.contains(ext) {
            return .recording
        }
        if lower.hasPrefix("screenshot") || lower.hasPrefix("screen shot"), imageExts.contains(ext) {
            return .screenshot
        }
        return nil
    }
}
