import Foundation

enum DirectorySizer {
    static func size(of urls: [URL]) -> UInt64 {
        urls.reduce(into: UInt64(0)) { $0 += size(of: $1) }
    }

    static func size(of url: URL) -> UInt64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }

        if !isDir.boolValue {
            return fileSize(url)
        }

        if let du = duSize(url) {
            return du
        }
        return enumerateSize(url)
    }

    private static func fileSize(_ url: URL) -> UInt64 {
        (try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]))
            .flatMap { $0.totalFileAllocatedSize.map(UInt64.init) ?? $0.fileAllocatedSize.map(UInt64.init) } ?? 0
    }

    private static func duSize(_ url: URL) -> UInt64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", url.path]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = out.fileHandleForReading.readDataToEndOfFile()
            guard let line = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0 == "\t" || $0 == " " })
                .first,
                let kb = UInt64(line)
            else {
                return nil
            }
            return kb * 1024
        } catch {
            return nil
        }
    }

    private static func enumerateSize(_ url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: [.skipsPackageDescendants]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .totalFileAllocatedSizeKey,
                .fileAllocatedSizeKey
            ]),
                values.isRegularFile == true else { continue }
            if let allocated = values.totalFileAllocatedSize {
                total += UInt64(allocated)
            } else if let allocated = values.fileAllocatedSize {
                total += UInt64(allocated)
            }
        }
        return total
    }
}
