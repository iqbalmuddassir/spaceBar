import Foundation

enum BuildArtifactScanner {
    static let minimumBytes: UInt64 = 10_000_000
    static let maximumDepth = 5
    /// Each candidate costs a `du`, so collection stops here rather than sizing the whole disk.
    static let maximumResults = 300

    private struct Candidate {
        let url: URL
        let projectURL: URL
        let rule: BuildArtifactRule
    }

    static func scan(
        roots: [URL]? = nil,
        minimumBytes: UInt64 = minimumBytes
    ) -> [ReviewableFile] {
        let candidates = collectCandidates(roots: roots ?? searchRoots())
        guard !candidates.isEmpty, !Task.isCancelled else { return [] }
        return measure(candidates)
            .filter { $0.byteSize >= minimumBytes }
            .sorted { $0.byteSize > $1.byteSize }
    }

    static func searchRoots() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let skipped: Set = [
            "library", "applications", "music", "pictures", "movies", "public", "sites"
        ]
        let children = (try? FileManager.default.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return children.filter { url in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true, values.isSymbolicLink != true else { return false }
            return !skipped.contains(url.lastPathComponent.lowercased())
        }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func collectCandidates(roots: [URL]) -> [Candidate] {
        var candidates: [Candidate] = []
        var stack: [(url: URL, depth: Int)] = roots.map { ($0, 0) }

        while let current = stack.popLast() {
            if Task.isCancelled || candidates.count >= maximumResults {
                break
            }
            let children = directoryChildren(of: current.url)
            guard !children.isEmpty else { continue }
            let siblingNames = Set(children.map { $0.lastPathComponent.lowercased() })

            for child in children where isTraversableDirectory(child) {
                if let rule = matchingRule(for: child, siblingNames: siblingNames) {
                    candidates.append(Candidate(url: child, projectURL: current.url, rule: rule))
                } else if current.depth < maximumDepth, !isSkippedBranch(child) {
                    stack.append((child, current.depth + 1))
                }
            }
        }

        return candidates
    }

    private static func matchingRule(for url: URL, siblingNames: Set<String>) -> BuildArtifactRule? {
        let rules = BuildArtifactRule.rule(forDirectoryNamed: url.lastPathComponent)
        guard !rules.isEmpty else { return nil }
        // Only content-marker rules need this, and listing node_modules is not free.
        var contents: Set<String>?
        let contentNames = {
            if let contents {
                return contents
            }
            let names = Set(directoryChildren(of: url).map { $0.lastPathComponent.lowercased() })
            contents = names
            return names
        }
        return rules.first { $0.isSatisfied(siblingNames: siblingNames, contentNames: contentNames()) }
    }

    private static func directoryChildren(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )) ?? []
    }

    private static func isTraversableDirectory(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else {
            return false
        }
        return values.isDirectory == true && values.isSymbolicLink != true
    }

    /// Hidden folders are only skipped here — a rule matching one has already claimed it above.
    private static func isSkippedBranch(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") {
            return true
        }
        let bundleExtensions: Set = [
            "app", "xcodeproj", "xcworkspace", "framework", "bundle", "playground",
            "photoslibrary", "musiclibrary", "tvlibrary", "fcpbundle", "sparsebundle", "download"
        ]
        return bundleExtensions.contains(url.pathExtension.lowercased())
    }

    private static func measure(_ candidates: [Candidate]) -> [ReviewableFile] {
        var files = [ReviewableFile?](repeating: nil, count: candidates.count)
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: candidates.count) { index in
            let candidate = candidates[index]
            let bytes = DirectorySizer.size(of: candidate.url)
            guard bytes > 0 else { return }
            let modified = (try? candidate.url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            let file = ReviewableFile(
                id: candidate.url,
                url: candidate.url,
                kind: .buildArtifact,
                byteSize: bytes,
                modified: modified,
                projectName: candidate.projectURL.lastPathComponent,
                detailLabel: candidate.rule.label,
                regenerationNote: candidate.rule.regenerationNote
            )
            lock.lock()
            files[index] = file
            lock.unlock()
        }

        return files.compactMap { $0 }
    }
}
