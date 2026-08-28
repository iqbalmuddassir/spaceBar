import Foundation

enum CommandSizeEstimator {
    static func simulatorUnavailableSize() -> UInt64 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let devices = home.appendingPathComponent("Library/Developer/CoreSimulator/Devices", isDirectory: true)
        guard FileManager.default.fileExists(atPath: devices.path) else { return 0 }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "unavailable"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty && !trimmed.hasPrefix("--") && !trimmed.hasPrefix("==")
            }
            guard !lines.isEmpty else { return 0 }

            var total: UInt64 = 0
            let uuidPattern = #/[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}/#
            for line in lines {
                if let match = line.firstMatch(of: uuidPattern) {
                    let uuid = String(match.output)
                    let dir = devices.appendingPathComponent(uuid, isDirectory: true)
                    total += DirectorySizer.size(of: dir)
                }
            }
            return total
        } catch {
            return 0
        }
    }

    static func dockerBuildCacheSize() -> UInt64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "system", "df", "--format", "{{.Type}} {{.Size}}"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return 0 }
            let output = String(data: outputData, encoding: .utf8) ?? ""
            for line in output.split(separator: "\n") where line.lowercased().contains("build cache") {
                return parseDockerSize(String(line.split(separator: " ").last ?? "0"))
            }
            return 0
        } catch {
            return 0
        }
    }

    static let unusedRuntimeThresholdDays = 30

    struct UnusedRuntime {
        let id: String
        let version: String
        let sizeBytes: UInt64
    }

    /// `--notUsedSinceDays` silently skips runtimes with no recorded `lastUsedAt`, so deletion
    /// targets identifiers directly instead.
    static func unusedSimulatorRuntimes() -> [UnusedRuntime] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "runtime", "list", "-j"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: outputData) as? [String: [String: Any]] else {
                return []
            }
            let cutoff = Date().addingTimeInterval(-Double(unusedRuntimeThresholdDays) * 86400)
            let formatter = ISO8601DateFormatter()
            var results: [UnusedRuntime] = []
            for (id, runtime) in json {
                guard runtime["deletable"] as? Bool == true else { continue }
                let lastUsedAt = (runtime["lastUsedAt"] as? String).flatMap { formatter.date(from: $0) }
                if let lastUsedAt, lastUsedAt >= cutoff {
                    continue
                }
                let bytes = (runtime["sizeBytes"] as? Int).map(UInt64.init) ?? 0
                let version = runtime["version"] as? String ?? id
                results.append(UnusedRuntime(id: id, version: version, sizeBytes: bytes))
            }
            return results
        } catch {
            return []
        }
    }

    static func simulatorUnusedRuntimeSize() -> UInt64 {
        unusedSimulatorRuntimes().reduce(0) { $0 + $1.sizeBytes }
    }

    static func dockerReclaimableSize() -> UInt64 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker", "system", "df", "--format", "{{.Type}}\t{{.Reclaimable}}"]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return 0 }
            let output = String(data: outputData, encoding: .utf8) ?? ""
            var total: UInt64 = 0
            for line in output.split(separator: "\n") {
                let parts = line.split(separator: "\t")
                guard parts.count == 2, !parts[0].lowercased().contains("build cache") else { continue }
                let sizePart = parts[1].split(separator: "(").first.map(String.init) ?? String(parts[1])
                total += parseDockerSize(sizePart)
            }
            return total
        } catch {
            return 0
        }
    }

    /// Approximates purgeable snapshot space via the gap between opportunistic and important
    /// available capacity, since local snapshots don't report a byte size directly.
    static func timeMachineLocalSnapshotSize() -> UInt64 {
        guard hasLocalSnapshots() else { return 0 }
        let root = URL(fileURLWithPath: "/")
        guard let values = try? root.resourceValues(forKeys: [
            .volumeAvailableCapacityForOpportunisticUsageKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) else { return 0 }
        let opportunistic = values.volumeAvailableCapacityForOpportunisticUsage ?? 0
        let important = values.volumeAvailableCapacityForImportantUsage ?? 0
        return opportunistic > important ? UInt64(opportunistic - important) : 0
    }

    private static func hasLocalSnapshots() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return false }
            let lines = String(data: outputData, encoding: .utf8)?
                .split(separator: "\n")
                .filter { $0.hasPrefix("com.apple.TimeMachine") } ?? []
            return !lines.isEmpty
        } catch {
            return false
        }
    }

    private static func parseDockerSize(_ raw: String) -> UInt64 {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let numberPart = String(trimmed.prefix(while: { $0.isNumber || $0 == "." || $0 == "," }))
            .replacingOccurrences(of: ",", with: "")
        guard let value = Double(numberPart) else { return 0 }
        if trimmed.contains("TB") {
            return UInt64(value * 1_000_000_000_000)
        }
        if trimmed.contains("GB") {
            return UInt64(value * 1_000_000_000)
        }
        if trimmed.contains("MB") {
            return UInt64(value * 1_000_000)
        }
        if trimmed.contains("KB") {
            return UInt64(value * 1000)
        }
        return UInt64(value)
    }
}
