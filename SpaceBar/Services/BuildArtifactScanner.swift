import Foundation

/// Finds regenerable build and dependency folders inside the code you keep on disk.
///
/// The walk is deliberately shallow and stops at the first artifact it finds on a branch: there is
/// no point descending into `node_modules` to find the `node_modules` inside it, and not descending
/// is what keeps a full-home scan to seconds rather than minutes.
enum BuildArtifactScanner {
    /// Anything smaller is noise in a list meant for reclaiming space — a `__pycache__` holding
    /// 40 KB costs more attention than it returns.
    static let minimumBytes: UInt64 = 10_000_000
    /// Depth below each search root. Five levels reaches `~/Code/work/client/app/node_modules`.
    static let maximumDepth = 5
    /// Sizing each folder costs a `du`, so the walk stops collecting once the list is long enough
    /// to be worth reviewing.
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

    /// Every non-hidden folder in the home folder except the ones macOS owns. Code lives in
    /// `~/Projects` for some people and `~/Documents/work` for others, so the roots are discovered
    /// rather than guessed.
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
        // Listing the folder is only needed by rules that look inside it (a virtualenv's
        // pyvenv.cfg), and listing something like node_modules is not free.
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

    /// Bundles look like folders and never hold projects; hidden folders are skipped unless a rule
    /// already claimed them above, so `.git` and `.vscode` cost nothing.
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
