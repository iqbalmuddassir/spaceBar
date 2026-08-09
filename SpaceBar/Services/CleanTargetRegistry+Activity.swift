import Foundation

extension CleanTargetRegistry {
    /// The verb each target's age is phrased with. Anything absent stays `.used`, which is
    /// the right word for a plain cache.
    static let activities: [String: CleanupActivity] = [
        "xcode-derived": .built,
        "xcode-archives": .built,
        "gradle-caches": .built,
        "docker-builder": .built,
        "xcode-devicesupport": .downloaded,
        "cocoapods": .downloaded,
        "swiftpm": .downloaded,
        "npm": .downloaded,
        "pnpm-store": .downloaded,
        "homebrew": .downloaded,
        "uv-cache": .downloaded,
        "pip": .downloaded,
        "simctl-unavailable": .booted,
        "android-avds": .booted,
        "empty-trash": .trashed
    ]
}
