import Foundation

extension CleanTargetRegistry {
    static func agenticAITargets(home: URL, caches: URL) -> [CleanTarget] {
        let appSupport = home.appendingPathComponent("Library/Application Support", isDirectory: true)
        var targets: [CleanTarget] = []
        targets.append(contentsOf: claudeTargets(appSupport: appSupport, caches: caches))
        targets.append(contentsOf: cursorTargets(appSupport: appSupport))
        targets.append(contentsOf: otherAITargets(home: home, caches: caches, appSupport: appSupport))
        return targets
    }

    private static func claudeTargets(appSupport: URL, caches: URL) -> [CleanTarget] {
        var targets: [CleanTarget] = []
        let claudeApp = appSupport.appendingPathComponent("Claude", isDirectory: true)
        targets.append(CleanTarget(
            id: "claude-desktop-cache",
            name: "Claude Desktop Cache",
            subtitle: tildePath(claudeApp.appendingPathComponent("Cache")),
            safetyNote: "Claude Desktop rebuilds these caches automatically on next launch.",
            strategy: .deletePaths([
                claudeApp.appendingPathComponent("Cache", isDirectory: true),
                claudeApp.appendingPathComponent("Code Cache", isDirectory: true),
                claudeApp.appendingPathComponent("GPUCache", isDirectory: true),
                claudeApp.appendingPathComponent("DawnWebGPUCache", isDirectory: true),
                claudeApp.appendingPathComponent("DawnGraphiteCache", isDirectory: true)
            ]),
            requiresStrongConfirm: false,
            isPermanent: false
        ))

        let claudeCliCache = caches.appendingPathComponent("claude-cli-nodejs", isDirectory: true)
        if FileManager.default.fileExists(atPath: claudeCliCache.path) {
            targets.append(CleanTarget(
                id: "claude-code-cli-cache",
                name: "Claude Code CLI Cache",
                subtitle: tildePath(claudeCliCache),
                safetyNote: "The CLI rebuilds its module cache on the next run.",
                strategy: .deletePaths([claudeCliCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }
        return targets
    }

    private static func cursorTargets(appSupport: URL) -> [CleanTarget] {
        let cursorApp = appSupport.appendingPathComponent("Cursor", isDirectory: true)
        guard FileManager.default.fileExists(atPath: cursorApp.path) else { return [] }

        let httpCache = CleanTarget(
            id: "cursor-cache",
            name: "Cursor Cache",
            subtitle: tildePath(cursorApp.appendingPathComponent("Cache")),
            safetyNote: "Cursor rebuilds HTTP and GPU caches automatically on next launch.",
            strategy: .deletePaths([
                cursorApp.appendingPathComponent("Cache", isDirectory: true),
                cursorApp.appendingPathComponent("Code Cache", isDirectory: true),
                cursorApp.appendingPathComponent("GPUCache", isDirectory: true),
                cursorApp.appendingPathComponent("DawnGraphiteCache", isDirectory: true),
                cursorApp.appendingPathComponent("DawnWebGPUCache", isDirectory: true)
            ]),
            requiresStrongConfirm: false,
            isPermanent: false
        )

        let extCache = CleanTarget(
            id: "cursor-cached-data",
            name: "Cursor Extension Cache",
            subtitle: tildePath(cursorApp.appendingPathComponent("CachedData")),
            safetyNote: "Language server binaries are re-downloaded on next launch. First launch may be slower.",
            strategy: .deletePaths([
                cursorApp.appendingPathComponent("CachedData", isDirectory: true),
                cursorApp.appendingPathComponent("CachedExtensionVSIXs", isDirectory: true),
                cursorApp.appendingPathComponent("CachedProfilesData", isDirectory: true),
                cursorApp.appendingPathComponent("CachedConfigurations", isDirectory: true)
            ]),
            requiresStrongConfirm: false,
            isPermanent: false
        )
        return [httpCache, extCache]
    }

    private static func otherAITargets(home: URL, caches: URL, appSupport: URL) -> [CleanTarget] {
        var targets: [CleanTarget] = []

        let windsurfApp = appSupport.appendingPathComponent("Windsurf", isDirectory: true)
        if FileManager.default.fileExists(atPath: windsurfApp.path) {
            targets.append(CleanTarget(
                id: "windsurf-cache",
                name: "Windsurf Cache",
                subtitle: tildePath(windsurfApp.appendingPathComponent("Cache")),
                safetyNote: "Windsurf rebuilds its caches automatically on next launch.",
                strategy: .deletePaths([
                    windsurfApp.appendingPathComponent("Cache", isDirectory: true),
                    windsurfApp.appendingPathComponent("Code Cache", isDirectory: true),
                    windsurfApp.appendingPathComponent("GPUCache", isDirectory: true),
                    windsurfApp.appendingPathComponent("CachedData", isDirectory: true),
                    windsurfApp.appendingPathComponent("CachedExtensionVSIXs", isDirectory: true)
                ]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let ollamaCache = caches.appendingPathComponent("ollama", isDirectory: true)
        if FileManager.default.fileExists(atPath: ollamaCache.path) {
            targets.append(CleanTarget(
                id: "ollama-cache",
                name: "Ollama Cache",
                subtitle: tildePath(ollamaCache),
                safetyNote: "Cached model blobs will be re-downloaded when you next run a model.",
                strategy: .deletePaths([ollamaCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let continueCache = home.appendingPathComponent(".continue/cache", isDirectory: true)
        if FileManager.default.fileExists(atPath: continueCache.path) {
            targets.append(CleanTarget(
                id: "continue-cache",
                name: "Continue Cache",
                subtitle: tildePath(continueCache),
                safetyNote: "Continue will rebuild its embedding and context cache on next use.",
                strategy: .deletePaths([continueCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let codexCache = home.appendingPathComponent(".codex/cache", isDirectory: true)
        if FileManager.default.fileExists(atPath: codexCache.path) {
            targets.append(CleanTarget(
                id: "codex-cache",
                name: "Codex CLI Cache",
                subtitle: tildePath(codexCache),
                safetyNote: "Codex CLI will rebuild its cache on the next run.",
                strategy: .deletePaths([codexCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        return targets
    }
}
