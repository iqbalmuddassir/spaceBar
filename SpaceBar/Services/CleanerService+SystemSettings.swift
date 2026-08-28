import AppKit
import Foundation

extension CleanerService {
    static func hasFullDiskAccess() -> Bool {
        let probes = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
        ]
        for url in probes {
            do {
                _ = try FileManager.default.contentsOfDirectory(atPath: url.path)
                return true
            } catch {
                continue
            }
        }
        return false
    }

    static func openFullDiskAccessSettings() {
        revealInFullDiskAccessList()
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        ]
        for url in urls where shellOpen(url) {
            activateSystemSettings()
            return
        }
        _ = shellOpen("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        activateSystemSettings()
    }

    static func openAutomationSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        ]
        for url in urls where shellOpen(url) {
            activateSystemSettings()
            return
        }
        _ = shellOpen("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
        activateSystemSettings()
    }

    private static func revealInFullDiskAccessList() {
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Safari/Bookmarks.plist"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mail")
        ]
        for url in candidates {
            _ = try? Data(contentsOf: url, options: [.mappedIfSafe])
            _ = try? FileManager.default.contentsOfDirectory(atPath: url.path)
        }
    }

    @discardableResult
    private static func shellOpen(_ urlString: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
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

    private static func activateSystemSettings() {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/System Settings.app"),
            configuration: config
        ) { _, _ in }
    }
}
