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
        "empty-trash": .trashed,
        "claude-desktop-cache": .used,
        "claude-code-cli-cache": .used,
        "cursor-cache": .used,
        "cursor-cached-data": .downloaded,
        "windsurf-cache": .used,
        "ollama-cache": .downloaded,
        "continue-cache": .used,
        "codex-cache": .used,
        "cargo-registry": .downloaded,
        "go-mod-cache": .downloaded,
        "go-build-cache": .built,
        "bun-cache": .downloaded,
        "yarn-cache": .downloaded,
        "node-gyp-cache": .downloaded,
        "nix-eval-cache": .used,
        "bazel-repo-cache": .downloaded,
        "bazelisk-cache": .downloaded,
        "vscode-cache": .used
    ]
}
