import Foundation

enum ReviewableFileScanner {
    static func scan(category: ReviewableFileCategory) -> [ReviewableFile] {
        if category == .projectBuildFiles {
            return BuildArtifactScanner.scan()
        }

        let allowedKinds = Set(category.kinds)
        var files: [ReviewableFile] = []
        var seenPaths = Set<String>()

        for directory in searchDirectories(for: category) {
            if Task.isCancelled {
                break
            }
            collectFiles(in: directory, matching: allowedKinds, into: &files, seenPaths: &seenPaths)
        }

        return files.sorted { $0.modified > $1.modified }
    }

    static func searchDirectories(for category: ReviewableFileCategory) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var directories: [URL]
        switch category {
        case .screenshotsAndRecordings:
            directories = [
                home.appendingPathComponent("Desktop", isDirectory: true),
                home.appendingPathComponent("Pictures", isDirectory: true),
                home.appendingPathComponent("Pictures/Screenshots", isDirectory: true),
                home.appendingPathComponent("Movies", isDirectory: true),
                home.appendingPathComponent("Downloads", isDirectory: true)
            ]
            if let custom = screenCaptureLocation(), DeletePathGuard.isUnderHome(custom) {
                directories.append(custom)
            }
        case .installerPackages:
            directories = [
                home.appendingPathComponent("Downloads", isDirectory: true),
                home.appendingPathComponent("Desktop", isDirectory: true)
            ]
        case .projectBuildFiles:
            directories = BuildArtifactScanner.searchRoots()
        }

        return existingUniqueDirectories(directories)
    }

    private static func existingUniqueDirectories(_ directories: [URL]) -> [URL] {
        var seen = Set<String>()
        return directories.filter { url in
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return FileManager.default.fileExists(atPath: path)
        }
    }

    private static func collectFiles(
        in directory: URL,
        matching allowedKinds: Set<ReviewableFileKind>,
        into files: inout [ReviewableFile],
        seenPaths: inout Set<String>
    ) {
        let maxDepth = depthLimit(for: directory)
        var stack: [(url: URL, depth: Int)] = [(directory, 0)]

        while let current = stack.popLast() {
            if Task.isCancelled {
                return
            }

            let names = (try? FileManager.default.contentsOfDirectory(
                at: current.url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

            for child in names where !isProtectedMediaBundle(child) {
                let standardized = child.standardizedFileURL
                let path = standardized.path
                guard seenPaths.insert(path).inserted else { continue }

                guard let values = try? standardized.resourceValues(forKeys: [.isRegularFileKey]) else { continue }
                if values.isRegularFile == true {
                    if let kind = classify(standardized), allowedKinds.contains(kind) {
                        if let file = makeReviewableFile(at: standardized, kind: kind) {
                            files.append(file)
                        }
                    }
                } else if current.depth < maxDepth {
                    stack.append((standardized, current.depth + 1))
                }
            }
        }
    }

    private static func isProtectedMediaBundle(_ url: URL) -> Bool {
        let mediaExtensions: Set = ["photoslibrary", "musiclibrary", "tvlibrary"]
        if mediaExtensions.contains(url.pathExtension.lowercased()) {
            return true
        }
        let name = url.lastPathComponent.lowercased()
        let parent = url.deletingLastPathComponent().lastPathComponent.lowercased()
        return (name == "tv" && parent == "movies") || (name == "music" && parent == "music")
    }

    private static func makeReviewableFile(at url: URL, kind: ReviewableFileKind) -> ReviewableFile? {
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
            .isRegularFileKey
        ])
        guard values?.isRegularFile == true else { return nil }
        let size = UInt64(values?.totalFileAllocatedSize ?? values?.fileSize ?? 0)
        guard size > 0 else { return nil }
        let modified = values?.contentModificationDate ?? .distantPast
        return ReviewableFile(id: url, url: url, kind: kind, byteSize: size, modified: modified)
    }

    private static func depthLimit(for directory: URL) -> Int {
        let name = directory.lastPathComponent.lowercased()
        if name == "pictures" || name == "movies" || name == "screenshots" {
            return 2
        }
        return 1
    }

    private static let installerExtensions: Set = ["dmg", "pkg", "iso"]
    private static let recordingExtensions: Set = ["mov", "mp4", "m4v"]
    private static let screenshotExtensions: Set = ["png", "jpg", "jpeg", "heic"]

    private static func classify(_ url: URL) -> ReviewableFileKind? {
        let lowerName = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        if recordingExtensions.contains(ext), isScreenRecordingName(lowerName) {
            return .recording
        }
        if screenshotExtensions.contains(ext), isScreenshotName(lowerName) {
            return .screenshot
        }
        if installerExtensions.contains(ext) {
            return .installer
        }
        return nil
    }

    private static func screenCaptureLocation() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", "com.apple.screencapture", "location"]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            let outputData = out.fileHandleForReading.readDataToEndOfFile()
            _ = err.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let path = String(data: outputData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty else { return nil }
            let expanded = (path as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expanded, isDirectory: true)
        } catch {
            return nil
        }
    }

    private static func isScreenRecordingName(_ lower: String) -> Bool {
        lower.hasPrefix("screen recording")
            || lower.hasPrefix("screen_recording")
            || lower.hasPrefix("screenrecording")
    }

    private static func isScreenshotName(_ lower: String) -> Bool {
        lower.hasPrefix("screenshot")
            || lower.hasPrefix("screen shot")
            || lower.hasPrefix("screen_shot")
    }
}
