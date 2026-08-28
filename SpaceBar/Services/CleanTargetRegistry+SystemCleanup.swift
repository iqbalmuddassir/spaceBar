import Foundation

extension CleanTargetRegistry {
    /// OS-level cleanup targets not covered by the other groups.
    static func systemCleanupTargets(home: URL, developer: URL, dockerIsAvailable: Bool) -> [CleanTarget] {
        [timeMachineTarget()]
            + mobileSyncBackupsTarget(home: home)
            + diagnosticReportsTarget(home: home)
            + coreSimulatorCacheTarget(developer: developer)
            + [unusedSimulatorRuntimesTarget()]
            + dockerSystemPruneTarget(dockerIsAvailable: dockerIsAvailable)
    }

    private static func timeMachineTarget() -> CleanTarget {
        CleanTarget(
            id: "tm-local-snapshots",
            name: "Time Machine Local Snapshots",
            subtitle: "via tmutil",
            safetyNote: "Thins local snapshots kept for Time Machine's browsable history. "
                + "Your actual Time Machine backups on an external disk or network share are untouched.",
            strategy: .timeMachineThinLocalSnapshots,
            requiresStrongConfirm: true,
            isPermanent: false
        )
    }

    private static func mobileSyncBackupsTarget(home: URL) -> [CleanTarget] {
        let mobileSyncBackup = home
            .appendingPathComponent("Library/Application Support/MobileSync/Backup", isDirectory: true)
        guard FileManager.default.fileExists(atPath: mobileSyncBackup.path) else { return [] }
        return [
            CleanTarget(
                id: "mobilesync-backups",
                name: "iOS Device Backups",
                subtitle: tildePath(mobileSyncBackup),
                safetyNote: "Deletes local backups made via Finder/iTunes for physical iPhones and iPads. "
                    + "You'll need a fresh backup before restoring or migrating a device.",
                strategy: .deletePaths([mobileSyncBackup]),
                requiresStrongConfirm: true,
                isPermanent: false
            )
        ]
    }

    private static func diagnosticReportsTarget(home: URL) -> [CleanTarget] {
        let diagnosticReports = home.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        guard FileManager.default.fileExists(atPath: diagnosticReports.path) else { return [] }
        return [
            CleanTarget(
                id: "diagnostic-reports",
                name: "Diagnostic & Crash Reports",
                subtitle: tildePath(diagnosticReports),
                safetyNote: "Only useful for debugging past crashes and hangs; "
                    + "macOS regenerates the folder as needed.",
                strategy: .deletePaths([diagnosticReports]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }

    private static func coreSimulatorCacheTarget(developer: URL) -> [CleanTarget] {
        let coreSimulatorCaches = developer
            .deletingLastPathComponent()
            .appendingPathComponent("CoreSimulator/Caches", isDirectory: true)
        guard FileManager.default.fileExists(atPath: coreSimulatorCaches.path) else { return [] }
        return [
            CleanTarget(
                id: "coresimulator-cache",
                name: "CoreSimulator Cache",
                subtitle: tildePath(coreSimulatorCaches),
                safetyNote: "Separate from your simulator devices' own data; regenerated automatically.",
                strategy: .deletePaths([coreSimulatorCaches]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }

    private static func unusedSimulatorRuntimesTarget() -> CleanTarget {
        CleanTarget(
            id: "simctl-unused-runtimes",
            name: "Unused iOS Simulator Runtimes",
            subtitle: "via xcrun simctl runtime",
            safetyNote: "Unregisters simulator OS runtimes not used in the last "
                + "\(CommandSizeEstimator.unusedRuntimeThresholdDays) days. Xcode re-downloads a "
                + "runtime automatically the next time you need it. The underlying disk image is a "
                + "system-managed asset cache (under /System) that macOS reclaims on its own schedule, "
                + "not necessarily right away — free space may not increase immediately.",
            strategy: .simctlDeleteUnusedRuntimes,
            requiresStrongConfirm: false,
            isPermanent: false
        )
    }

    private static func dockerSystemPruneTarget(dockerIsAvailable: Bool) -> [CleanTarget] {
        guard dockerIsAvailable else { return [] }
        return [
            CleanTarget(
                id: "docker-system-prune",
                name: "Docker Images, Containers & Volumes",
                subtitle: "via docker system prune",
                safetyNote: "Removes all stopped containers, unused networks, dangling and unreferenced "
                    + "images, and volumes not used by a running container. Anything you still need must "
                    + "be running or explicitly tagged/in use.",
                strategy: .dockerSystemPrune,
                requiresStrongConfirm: true,
                isPermanent: false
            )
        ]
    }
}
