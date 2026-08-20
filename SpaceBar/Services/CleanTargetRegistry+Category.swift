import Foundation

extension CleanTargetRegistry {
    /// Anything absent stays `.general`, the right bucket for a plain, uncategorized cache.
    static let categories: [String: CleanTargetCategory] = [
        "xcode-derived": .xcode,
        "xcode-archives": .xcode,
        "xcode-devicesupport": .xcode,
        "simctl-unavailable": .xcode,
        "android-avds": .mobile,
        "gradle-caches": .mobile,
        "cocoapods": .packageManagers,
        "swiftpm": .packageManagers,
        "npm": .packageManagers,
        "pnpm-store": .packageManagers,
        "cargo-registry": .packageManagers,
        "go-mod-cache": .packageManagers,
        "bun-cache": .packageManagers,
        "yarn-cache": .packageManagers,
        "node-gyp-cache": .packageManagers,
        "homebrew": .devTools,
        "uv-cache": .devTools,
        "pip": .devTools,
        "docker-builder": .devTools,
        "go-build-cache": .devTools,
        "nix-eval-cache": .devTools,
        "bazel-repo-cache": .devTools,
        "vscode-cache": .devTools,
        "claude-desktop-cache": .aiTools,
        "claude-code-cli-cache": .aiTools,
        "cursor-cache": .aiTools,
        "cursor-cached-data": .aiTools,
        "windsurf-cache": .aiTools,
        "ollama-cache": .aiTools,
        "continue-cache": .aiTools,
        "codex-cache": .aiTools,
        "empty-trash": .trash
    ]
}
