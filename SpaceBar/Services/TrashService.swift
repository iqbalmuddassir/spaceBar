import Foundation

struct TrashInfo {
    let itemCount: Int
    let byteSize: UInt64
}

enum TrashService {
    static func info() -> TrashInfo {
        if let count = finderItemCount(), count == 0 {
            return TrashInfo(itemCount: 0, byteSize: 0)
        }

        if let direct = directTrashInfo(), direct.itemCount >= 0 {
            return direct
        }

        if let summed = finderSummedItemSizes() {
            return summed
        }

        if let count = finderItemCount() {
            return TrashInfo(itemCount: count, byteSize: 0)
        }

        return TrashInfo(itemCount: 0, byteSize: 0)
    }

    static func empty() throws {
        let script = """
        tell application "Finder"
          if (count of items of trash) > 0 then
            empty the trash
          end if
        end tell
        """
        if runAppleScriptReturningError(script) != nil {
            do {
                try emptyDirectly()
            } catch {
                throw CleanerError.commandFailed(error.localizedDescription)
            }
            return
        }
    }

    private static func finderItemCount() -> Int? {
        let script = """
        tell application "Finder"
          try
            return (count of items of trash) as string
          on error
            return "ERR"
          end try
        end tell
        """
        guard let output = runAppleScript(script), output != "ERR", let count = Int(output) else {
            return nil
        }
        return count
    }

    private static func finderSummedItemSizes() -> TrashInfo? {
        let script = """
        tell application "Finder"
          try
            set n to count of items of trash
            if n is 0 then return "0|0"
            set total to 0
            repeat with i in (get items of trash)
              try
                set total to total + ((physical size of i) as real)
              on error
                try
                  set total to total + ((size of i) as real)
                end try
              end try
            end repeat
            return (n as string) & "|" & (total as string)
          on error
            return "ERR"
          end try
        end tell
        """
        guard let output = runAppleScript(script), output != "ERR" else { return nil }
        let parts = output.split(separator: "|", maxSplits: 1).map(String.init)
        let count = Int(parts.first ?? "0") ?? 0
        let parsedSize: Double? = parts.count > 1
            ? Double(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
            : nil
        let size = parsedSize.map { UInt64(max(0, $0.rounded())) } ?? 0
        if count == 0 {
            return TrashInfo(itemCount: 0, byteSize: 0)
        }
        return TrashInfo(itemCount: count, byteSize: size)
    }

    private static func directTrashInfo() -> TrashInfo? {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        guard FileManager.default.fileExists(atPath: trash.path) else {
            return TrashInfo(itemCount: 0, byteSize: 0)
        }
        do {
            let children = try FileManager.default.contentsOfDirectory(
                at: trash,
                includingPropertiesForKeys: nil,
                options: []
            )
            let size = DirectorySizer.size(of: trash)
            return TrashInfo(itemCount: children.count, byteSize: size)
        } catch {
            return nil
        }
    }

    private static func emptyDirectly() throws {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        try DeletePathGuard.validateForCleanupDelete(trash)
        let fm = FileManager.default
        guard fm.fileExists(atPath: trash.path) else { return }
        let children = try fm.contentsOfDirectory(at: trash, includingPropertiesForKeys: nil, options: [])
        for child in children {
            try DeletePathGuard.validateForCleanupDelete(child)
            try fm.removeItem(at: child)
        }
    }

    private static func runAppleScript(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static func runAppleScriptReturningError(_ source: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return nil
            }
            let message = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return message?.isEmpty == false ? message : "Failed to empty Trash"
        } catch {
            return error.localizedDescription
        }
    }
}
