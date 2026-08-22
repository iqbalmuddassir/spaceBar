import Foundation

extension CleanTargetRegistry {
    /// Caches outside `~/Library/Caches` the generic App Caches sweep never sees, plus a few
    /// pulled out of that sweep by name for visibility, like CocoaPods/npm/Homebrew already are.
    static func devCacheTargets(home: URL, caches: URL) -> [CleanTarget] {
        goTargets(home: home, caches: caches)
            + jsToolingTargets(home: home, caches: caches)
            + toolDevCaches(home: home, caches: caches)
    }

    private static func goTargets(home: URL, caches: URL) -> [CleanTarget] {
        var targets: [CleanTarget] = []

        let cargoRegistry = home.appendingPathComponent(".cargo/registry", isDirectory: true)
        if FileManager.default.fileExists(atPath: cargoRegistry.path) {
            targets.append(CleanTarget(
                id: "cargo-registry",
                name: "Cargo Registry Cache",
                subtitle: tildePath(cargoRegistry),
                safetyNote: "cargo re-downloads crate sources and index data as needed.",
                strategy: .deletePaths([cargoRegistry]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let goModFallback = home.appendingPathComponent("go/pkg/mod", isDirectory: true)
        if let goModCache = goEnv("GOMODCACHE", fallback: goModFallback) {
            targets.append(CleanTarget(
                id: "go-mod-cache",
                name: "Go Module Cache",
                subtitle: tildePath(goModCache),
                safetyNote: "go re-downloads modules on the next build.",
                strategy: .deletePaths([goModCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let goBuildFallback = caches.appendingPathComponent("go-build", isDirectory: true)
        if let goBuildCache = goEnv("GOCACHE", fallback: goBuildFallback) {
            targets.append(CleanTarget(
                id: "go-build-cache",
                name: "Go Build Cache",
                subtitle: tildePath(goBuildCache),
                safetyNote: "go rebuilds cached packages on the next build.",
                strategy: .deletePaths([goBuildCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        return targets
    }

    private static func jsToolingTargets(home: URL, caches: URL) -> [CleanTarget] {
        var targets: [CleanTarget] = []

        let bunCache = home.appendingPathComponent(".bun/install/cache", isDirectory: true)
        if FileManager.default.fileExists(atPath: bunCache.path) {
            targets.append(CleanTarget(
                id: "bun-cache",
                name: "Bun Cache",
                subtitle: tildePath(bunCache),
                safetyNote: "bun re-downloads packages into its cache as needed.",
                strategy: .deletePaths([bunCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let yarnCache = caches.appendingPathComponent("Yarn", isDirectory: true)
        if FileManager.default.fileExists(atPath: yarnCache.path) {
            targets.append(CleanTarget(
                id: "yarn-cache",
                name: "Yarn Cache",
                subtitle: tildePath(yarnCache),
                safetyNote: "yarn re-downloads cached packages as needed.",
                strategy: .deletePaths([yarnCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let nodeGyp = home.appendingPathComponent(".node-gyp", isDirectory: true)
        if FileManager.default.fileExists(atPath: nodeGyp.path) {
            targets.append(CleanTarget(
                id: "node-gyp-cache",
                name: "node-gyp Cache",
                subtitle: tildePath(nodeGyp),
                safetyNote: "Re-downloaded automatically the next time a native module builds.",
                strategy: .deletePaths([nodeGyp]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        return targets
    }

    private static func toolDevCaches(home: URL, caches: URL) -> [CleanTarget] {
        var targets: [CleanTarget] = []

        let nixCache = caches.appendingPathComponent("nix", isDirectory: true)
        if FileManager.default.fileExists(atPath: nixCache.path) {
            targets.append(CleanTarget(
                id: "nix-eval-cache",
                name: "Nix Eval Cache",
                subtitle: tildePath(nixCache),
                safetyNote: "nix re-evaluates and re-fetches as needed. This is only the eval/fetch "
                    + "cache — the Nix store itself needs nix-collect-garbage, not a file delete.",
                strategy: .deletePaths([nixCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let bazelRepoCache = caches.appendingPathComponent("bazel", isDirectory: true)
        if FileManager.default.fileExists(atPath: bazelRepoCache.path) {
            targets.append(CleanTarget(
                id: "bazel-repo-cache",
                name: "Bazel Repository Cache",
                subtitle: tildePath(bazelRepoCache),
                safetyNote: "Bazel re-downloads external dependencies as needed. This is only the "
                    + "repository cache — the build output base under /var/tmp isn't touched, since "
                    + "removing it while bazel's local server is running can corrupt an in-progress build.",
                strategy: .deletePaths([bazelRepoCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        let bazeliskCache = bazeliskCacheURL(home: home, caches: caches)
        if FileManager.default.fileExists(atPath: bazeliskCache.path) {
            targets.append(CleanTarget(
                id: "bazelisk-cache",
                name: "Bazelisk Cache",
                subtitle: tildePath(bazeliskCache),
                safetyNote: "Bazelisk re-downloads the pinned Bazel release binaries as needed.",
                strategy: .deletePaths([bazeliskCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ))
        }

        targets.append(contentsOf: vscodeTargets(home: home))
        return targets
    }

    /// Mirrors `uvCacheURL`: Bazelisk honors `BAZELISK_HOME` for a relocated cache dir,
    /// falling back to its default under `~/Library/Caches/bazelisk`.
    private static func bazeliskCacheURL(home: URL, caches: URL) -> URL {
        let fallback = caches.appendingPathComponent("bazelisk", isDirectory: true)
        if let env = ProcessInfo.processInfo.environment["BAZELISK_HOME"], !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            return DeletePathGuard.constrainedToolCacheURL(url, requiredPathFragment: "bazelisk") ?? fallback
        }
        return fallback
    }

    private static func vscodeTargets(home: URL) -> [CleanTarget] {
        let vscodeApp = home.appendingPathComponent("Library/Application Support/Code", isDirectory: true)
        guard FileManager.default.fileExists(atPath: vscodeApp.path) else { return [] }

        return [
            CleanTarget(
                id: "vscode-cache",
                name: "VS Code Cache",
                subtitle: tildePath(vscodeApp.appendingPathComponent("Cache")),
                safetyNote: "VS Code rebuilds HTTP, GPU and extension caches automatically on next launch.",
                strategy: .deletePaths([
                    vscodeApp.appendingPathComponent("Cache", isDirectory: true),
                    vscodeApp.appendingPathComponent("Code Cache", isDirectory: true),
                    vscodeApp.appendingPathComponent("GPUCache", isDirectory: true),
                    vscodeApp.appendingPathComponent("CachedData", isDirectory: true),
                    vscodeApp.appendingPathComponent("CachedExtensionVSIXs", isDirectory: true)
                ]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }

    /// Mirrors `detectPnpmStore()`: ask the tool for its real cache directory rather than
    /// guessing, since GOPATH/GOCACHE are commonly relocated by env vars or `go env -w`.
    private static func goEnv(_ key: String, fallback: URL) -> URL? {
        guard toolAvailable("go") else { return nil }

        let url = queriedGoPath(key: key) ?? fallback
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let safe = DeletePathGuard.constrainedToolCacheURL(url, requiredPathFragment: nil) else { return nil }
        // A customized GOMODCACHE/GOCACHE can point outside what DeletePathGuard allows deleting —
        // don't surface a row that would fail to clean when selected.
        guard (try? DeletePathGuard.validateForCleanupDelete(safe)) != nil else { return nil }
        return safe
    }

    private static func queriedGoPath(key: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["go", "env", key]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            guard let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path, isDirectory: true)
        } catch {
            return nil
        }
    }

    private static func toolAvailable(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [name, "version"]
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
}
