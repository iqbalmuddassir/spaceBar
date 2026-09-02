import Foundation

extension CleanTargetRegistry {
    /// Anything absent stays `.general`, the right bucket for a plain, uncategorized cache.
    static let categories: [String: CleanTargetCategory] = [
        // Xcode & iOS Simulator
        "xcode-derived": .xcodeDev,
        "xcode-archives": .xcodeDev,
        "xcode-devicesupport": .xcodeDev,
        "xcode-previews": .xcodeDev,
        "xcode-documentation-cache": .xcodeDev,
        "xcode-coding-assistant": .xcodeDev,
        "simctl-unavailable": .xcodeDev,
        "simctl-unused-runtimes": .xcodeDev,
        "coresimulator-cache": .xcodeDev,
        "cocoapods": .xcodeDev,
        "swiftpm": .xcodeDev,

        // Android & Emulator
        "gradle-caches": .androidDev,
        "android-avds": .androidDev,
        "android-studio-logs": .androidDev,
        "android-studio-captures": .androidDev,
        "android-studio-oom-heap-dump": .androidDev,
        "android-emulator-cache": .androidDev,

        // Python
        "pip": .pythonDev,
        "uv-cache": .pythonDev,
        "poetry-cache": .pythonDev,
        "conda-pkgs-cache": .pythonDev,

        // JavaScript & Node
        "npm": .jsDev,
        "pnpm-store": .jsDev,
        "bun-cache": .jsDev,
        "yarn-cache": .jsDev,
        "node-gyp-cache": .jsDev,

        // Build Tools
        "cargo-registry": .buildTools,
        "go-mod-cache": .buildTools,
        "go-build-cache": .buildTools,
        "nix-eval-cache": .buildTools,
        "bazel-repo-cache": .buildTools,
        "bazelisk-cache": .buildTools,
        "rustup-downloads-cache": .buildTools,
        "composer-cache": .buildTools,

        // Developer Tools
        "homebrew": .devTools,
        "docker-builder": .devTools,
        "docker-system-prune": .devTools,
        "vscode-cache": .devTools,
        "vscode-logs": .devTools,
        "vscode-backups": .devTools,

        // AI Tools
        "claude-desktop-cache": .aiTools,
        "claude-desktop-crashpad": .aiTools,
        "claude-code-cli-cache": .aiTools,
        "cursor-cache": .aiTools,
        "cursor-cached-data": .aiTools,
        "cursor-logs": .aiTools,
        "cursor-backups": .aiTools,
        "windsurf-cache": .aiTools,
        "windsurf-logs": .aiTools,
        "windsurf-backups": .aiTools,
        "ollama-cache": .aiTools,
        "continue-cache": .aiTools,
        "codex-cache": .aiTools,

        // System
        "tm-local-snapshots": .system,
        "diagnostic-reports": .system,

        // Mobile Devices
        "mobilesync-backups": .mobileDevices,

        // Trash
        "empty-trash": .trash
    ]
}
