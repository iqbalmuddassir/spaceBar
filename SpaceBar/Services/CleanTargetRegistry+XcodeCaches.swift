import Foundation

extension CleanTargetRegistry {
    /// Xcode's regenerable side caches — preview clones, offline docs, assistant index. Kept
    /// apart from `xcodeTargets` so that list stays about build products and device support.
    static func xcodeCacheTargets(developer: URL) -> [CleanTarget] {
        let previews = developer.appendingPathComponent("UserData/Previews", isDirectory: true)
        let documentationCache = developer.appendingPathComponent("DocumentationCache", isDirectory: true)
        let codingAssistant = developer.appendingPathComponent("CodingAssistant", isDirectory: true)
        return [
            CleanTarget(
                id: "xcode-previews",
                name: "SwiftUI Preview Devices",
                subtitle: tildePath(previews),
                safetyNote: "Hidden simulator clones Xcode spins up for canvas previews; "
                    + "recreated on the next preview render.",
                strategy: .deletePaths([previews]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "xcode-documentation-cache",
                name: "Xcode Documentation Cache",
                subtitle: tildePath(documentationCache),
                safetyNote: "Offline documentation re-indexes in the background.",
                strategy: .deletePaths([documentationCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "xcode-coding-assistant",
                name: "Xcode Coding Assistant Cache",
                subtitle: tildePath(codingAssistant),
                safetyNote: "Model and index cache for Xcode's coding assistant; rebuilt on demand.",
                strategy: .deletePaths([codingAssistant]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }
}
