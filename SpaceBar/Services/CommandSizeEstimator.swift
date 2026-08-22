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

    private static func parseDockerSize(_ raw: String) -> UInt64 {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let numberPart = String(trimmed.prefix(while: { $0.isNumber || $0 == "." || $0 == "," }))
            .replacingOccurrences(of: ",", with: "")
        guard let value = Double(numberPart) else { return 0 }
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
