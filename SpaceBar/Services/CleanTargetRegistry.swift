import Foundation

enum CleanTargetRegistry {
    static func allTargets() -> [CleanTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let caches = library.appendingPathComponent("Caches", isDirectory: true)
        let developer = library.appendingPathComponent("Developer/Xcode", isDirectory: true)

        let specialtyTargets = specialtyTargetGroups(home: home, developer: developer, caches: caches)
        let dedicatedFolderNames = libraryCachesFolderNames(from: specialtyTargets, under: caches)

        var targets: [CleanTarget] = []
        targets.append(contentsOf: generalTargets(
            home: home,
            caches: caches,
            dedicatedFolderNames: dedicatedFolderNames
        ))
        targets.append(contentsOf: specialtyTargets)
        targets.append(emptyTrashTarget())
        return targets.map { target in
            var copy = target
            copy.activity = activities[target.id] ?? .used
            copy.category = categories[target.id] ?? .general
            return copy
        }
    }

    private static func generalTargets(
        home: URL,
        caches: URL,
        dedicatedFolderNames: Set<String>
    ) -> [CleanTarget] {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return [
            CleanTarget(
                id: "user-temp",
                name: "User Temporary Files",
                subtitle: tildePath(tmp),
                safetyNote: "Temporary files are regenerated as needed. Close apps using large temp files first.",
                strategy: .deletePaths([tmp]),
                requiresStrongConfirm: true,
                isPermanent: false
            ),
            CleanTarget(
                id: "app-caches",
                name: "App Caches",
                subtitle: tildePath(caches),
                safetyNote: "Apps rebuild caches on next launch; first launches may be slower.",
                strategy: .deletePaths(safeCacheChildren(
                    of: caches,
                    dedicatedFolderNames: dedicatedFolderNames
                )),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }

    private static func xcodeTargets(developer: URL) -> [CleanTarget] {
        let derivedData = developer.appendingPathComponent("DerivedData", isDirectory: true)
        let archives = developer.appendingPathComponent("Archives", isDirectory: true)
        let deviceSupport = developer.appendingPathComponent("iOS DeviceSupport", isDirectory: true)
        return [
            CleanTarget(
                id: "xcode-derived",
                name: "Xcode DerivedData",
                subtitle: tildePath(derivedData),
                safetyNote: "Xcode will rebuild DerivedData on the next build.",
                strategy: .deletePaths([derivedData]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "xcode-archives",
                name: "Xcode Archives",
                subtitle: tildePath(archives),
                safetyNote: "These are archived builds. Only remove ones you no longer need for distribution.",
                strategy: .deletePaths([archives]),
                requiresStrongConfirm: true,
                isPermanent: false
            ),
            CleanTarget(
                id: "xcode-devicesupport",
                name: "Xcode iOS DeviceSupport",
                subtitle: tildePath(deviceSupport),
                safetyNote: "Symbol files re-download when you connect a device.",
                strategy: .deletePaths([deviceSupport]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "simctl-unavailable",
                name: "Unavailable iOS Simulators",
                subtitle: "via xcrun simctl",
                safetyNote: "Only removes simulator devices marked unavailable.",
                strategy: .simctlDeleteUnavailable,
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }

    private static func androidAndBuildTargets(home: URL) -> [CleanTarget] {
        let avd = home.appendingPathComponent(".android/avd", isDirectory: true)
        let gradle = home.appendingPathComponent(".gradle/caches", isDirectory: true)
        return [
            CleanTarget(
                id: "android-avds",
                name: "Android AVDs",
                subtitle: tildePath(avd),
                safetyNote: "Deletes Android emulator virtual devices. You will need to recreate them.",
                strategy: .deletePaths([avd]),
                requiresStrongConfirm: true,
                isPermanent: false
            ),
            CleanTarget(
                id: "gradle-caches",
                name: "Gradle Caches",
                subtitle: tildePath(gradle),
                safetyNote: "Next Gradle build will re-download dependencies.",
                strategy: .deletePaths([gradle]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]
    }

    private static func packageManagerTargets(home: URL, caches: URL) -> [CleanTarget] {
        let cocoapods = caches.appendingPathComponent("CocoaPods", isDirectory: true)
        let spm = caches.appendingPathComponent("org.swift.swiftpm", isDirectory: true)
        let npm = home.appendingPathComponent(".npm/_cacache", isDirectory: true)
        var targets = [
            CleanTarget(
                id: "cocoapods",
                name: "CocoaPods Cache",
                subtitle: tildePath(cocoapods),
                safetyNote: "Pod installs will re-download cached specs and pods.",
                strategy: .deletePaths([cocoapods]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "swiftpm",
                name: "Swift Package Manager Cache",
                subtitle: tildePath(spm),
                safetyNote: "SwiftPM will re-fetch packages as needed.",
                strategy: .deletePaths([spm]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "npm",
                name: "npm Cache",
                subtitle: tildePath(npm),
                safetyNote: "npm will rebuild its package cache on demand.",
                strategy: .deletePaths([npm]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]

        if let pnpmStore = detectPnpmStore() {
            targets.append(
                CleanTarget(
                    id: "pnpm-store",
                    name: "pnpm Store",
                    subtitle: tildePath(pnpmStore),
                    safetyNote: "Shared package store. Projects may need to reinstall packages.",
                    strategy: .deletePaths([pnpmStore]),
                    requiresStrongConfirm: true,
                    isPermanent: false
                )
            )
        }
        return targets
    }

    private static func optionalToolTargets(home: URL, caches: URL) -> [CleanTarget] {
        let brew = caches.appendingPathComponent("Homebrew", isDirectory: true)
        let uvCache = uvCacheURL(home: home)
        let pip = caches.appendingPathComponent("pip", isDirectory: true)
        var targets = [
            CleanTarget(
                id: "homebrew",
                name: "Homebrew Cache",
                subtitle: tildePath(brew),
                safetyNote: "Downloaded bottles and source archives will be re-fetched when needed.",
                strategy: .deletePaths([brew]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "uv-cache",
                name: "uv Cache",
                subtitle: tildePath(uvCache),
                safetyNote: "uv will re-download Python packages into its cache.",
                strategy: .deletePaths([uvCache]),
                requiresStrongConfirm: false,
                isPermanent: false
            ),
            CleanTarget(
                id: "pip",
                name: "pip Cache",
                subtitle: tildePath(pip),
                safetyNote: "pip will re-download wheels and packages as needed.",
                strategy: .deletePaths([pip]),
                requiresStrongConfirm: false,
                isPermanent: false
            )
        ]

        if dockerAvailable() {
            targets.append(
                CleanTarget(
                    id: "docker-builder",
                    name: "Docker Build Cache",
                    subtitle: "via docker builder prune",
                    safetyNote: "Prunes build cache only; images and containers are kept.",
                    strategy: .dockerBuilderPrune,
                    requiresStrongConfirm: false,
                    isPermanent: false
                )
            )
        }
        return targets
    }

    private static func emptyTrashTarget() -> CleanTarget {
        CleanTarget(
            id: "empty-trash",
            name: "Empty Trash",
            subtitle: "Finder Trash",
            safetyNote: "Permanently deletes all items currently in Trash.",
            strategy: .emptyTrash,
            requiresStrongConfirm: true,
            isPermanent: true
        )
    }

    static func dedicatedLibraryCachesFolderNames() -> Set<String> {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let caches = library.appendingPathComponent("Caches", isDirectory: true)
        let developer = library.appendingPathComponent("Developer/Xcode", isDirectory: true)
        return libraryCachesFolderNames(
            from: specialtyTargetGroups(home: home, developer: developer, caches: caches),
            under: caches
        )
    }

    private static func specialtyTargetGroups(home: URL, developer: URL, caches: URL) -> [CleanTarget] {
        xcodeTargets(developer: developer)
            + androidAndBuildTargets(home: home)
            + packageManagerTargets(home: home, caches: caches)
            + optionalToolTargets(home: home, caches: caches)
            + devCacheTargets(home: home, caches: caches)
            + agenticAITargets(home: home, caches: caches)
    }

    static func libraryCachesFolderNames(from targets: [CleanTarget], under caches: URL) -> Set<String> {
        let cachesPath = caches.standardizedFileURL.path
        var names = Set<String>()
        for target in targets {
            guard case let .deletePaths(urls) = target.strategy else { continue }
            for url in urls {
                let standardized = url.standardizedFileURL
                if standardized.deletingLastPathComponent().path == cachesPath {
                    names.insert(standardized.lastPathComponent)
                }
            }
        }
        return names
    }

    static func tildePath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
