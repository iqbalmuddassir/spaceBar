import Foundation
@testable import SpaceBar

extension SnapshotFixtures {
    /// Settings snapshots pin the catalog so a reference image cannot depend on which
    /// developer tools happen to be installed on the recording machine.
    static func settingsTargets() -> [CleanTarget] {
        [
            catalogTarget(id: "user-temp", name: "User Temporary Files", category: .general),
            catalogTarget(id: "app-caches", name: "App Caches", category: .general),
            catalogTarget(id: "xcode-derived", name: "Xcode DerivedData", category: .xcodeDev),
            catalogTarget(id: "xcode-archives", name: "Xcode Archives", category: .xcodeDev),
            catalogTarget(id: "xcode-device-support", name: "Xcode iOS DeviceSupport", category: .xcodeDev),
            catalogTarget(id: "android-avd", name: "Android AVDs", category: .androidDev),
            catalogTarget(id: "gradle-caches", name: "Gradle Caches", category: .androidDev),
            catalogTarget(id: "uv-cache", name: "uv Cache", category: .pythonDev),
            catalogTarget(id: "pip-cache", name: "pip Cache", category: .pythonDev),
            catalogTarget(id: "npm", name: "npm Cache", category: .jsDev),
            catalogTarget(id: "homebrew", name: "Homebrew Cache", category: .devTools),
            catalogTarget(id: "diagnostic-reports", name: "Diagnostic & Crash Reports", category: .system),
            catalogTarget(id: "empty-trash", name: "Empty Trash", category: .trash, isPermanent: true)
        ]
    }

    private static func catalogTarget(
        id: String,
        name: String,
        category: CleanTargetCategory,
        isPermanent: Bool = false
    ) -> CleanTarget {
        CleanTarget(
            id: id,
            name: name,
            subtitle: "~/Library/Caches/\(id)",
            safetyNote: "\(name) rebuilds on demand.",
            strategy: .deletePaths([]),
            requiresStrongConfirm: false,
            isPermanent: isPermanent,
            category: category
        )
    }
}
