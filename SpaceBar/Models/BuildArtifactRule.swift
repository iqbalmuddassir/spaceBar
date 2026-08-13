import Foundation

struct BuildArtifactRule: Equatable {
    let directoryName: String
    /// Empty means the folder name alone qualifies it.
    let siblingMarkers: [String]
    let contentMarkers: [String]
    let label: String
    let regenerationNote: String

    init(
        _ directoryName: String,
        markers siblingMarkers: [String] = [],
        contains contentMarkers: [String] = [],
        label: String,
        note regenerationNote: String
    ) {
        self.directoryName = directoryName
        self.siblingMarkers = siblingMarkers
        self.contentMarkers = contentMarkers
        self.label = label
        self.regenerationNote = regenerationNote
    }

    static func marker(_ marker: String, matchesAnyOf names: Set<String>) -> Bool {
        if marker.hasPrefix("*") {
            let suffix = marker.dropFirst().lowercased()
            return names.contains { $0.hasSuffix(suffix) }
        }
        return names.contains(marker.lowercased())
    }

    func isSatisfied(siblingNames: Set<String>, contentNames: @autoclosure () -> Set<String>) -> Bool {
        if !siblingMarkers.isEmpty {
            guard siblingMarkers.contains(where: { Self.marker($0, matchesAnyOf: siblingNames) }) else {
                return false
            }
        }
        if !contentMarkers.isEmpty {
            let contents = contentNames()
            guard contentMarkers.contains(where: { Self.marker($0, matchesAnyOf: contents) }) else {
                return false
            }
        }
        return true
    }
}

extension BuildArtifactRule {
    /// Order matters: the first rule whose markers match wins.
    static let all: [BuildArtifactRule] = javaScriptRules + appleRules + jvmRules + systemsRules + scriptingRules

    private static let javaScriptRules: [BuildArtifactRule] = [
        BuildArtifactRule(
            "node_modules",
            markers: ["package.json"],
            label: "Node dependencies",
            note: "npm install (or yarn/pnpm install) puts it back."
        ),
        BuildArtifactRule(
            ".next",
            markers: ["package.json"],
            label: "Next.js build output",
            note: "The next build regenerates it."
        ),
        BuildArtifactRule(
            ".nuxt",
            markers: ["package.json"],
            label: "Nuxt build output",
            note: "The next build regenerates it."
        ),
        BuildArtifactRule(
            ".svelte-kit",
            markers: ["package.json"],
            label: "SvelteKit build output",
            note: "The next build regenerates it."
        ),
        BuildArtifactRule(
            ".angular",
            markers: ["package.json"],
            label: "Angular build cache",
            note: "The next build regenerates it."
        ),
        BuildArtifactRule(
            ".turbo",
            markers: ["package.json"],
            label: "Turborepo cache",
            note: "The next task run refills it."
        ),
        BuildArtifactRule(
            ".parcel-cache",
            markers: ["package.json"],
            label: "Parcel cache",
            note: "The next build refills it."
        ),
        BuildArtifactRule(
            "dist",
            markers: ["package.json"],
            label: "Bundler output",
            note: "The project's build script regenerates it."
        ),
        BuildArtifactRule(
            "coverage",
            markers: ["package.json"],
            label: "Coverage report",
            note: "The next test run with coverage regenerates it."
        )
    ]

    private static let appleRules: [BuildArtifactRule] = [
        BuildArtifactRule(
            "DerivedData",
            markers: ["*.xcodeproj", "*.xcworkspace", "Package.swift"],
            label: "Xcode derived data",
            note: "Xcode rebuilds it on the next build."
        ),
        BuildArtifactRule(
            "Pods",
            markers: ["Podfile"],
            label: "CocoaPods dependencies",
            note: "pod install puts them back."
        ),
        BuildArtifactRule(
            "Carthage",
            markers: ["Cartfile", "Cartfile.resolved"],
            label: "Carthage dependencies",
            note: "carthage bootstrap puts them back."
        ),
        BuildArtifactRule(
            ".build",
            markers: ["Package.swift"],
            label: "SwiftPM build output",
            note: "swift build regenerates it."
        )
    ]

    private static let jvmRules: [BuildArtifactRule] = [
        BuildArtifactRule(
            "build",
            markers: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
            label: "Gradle build output",
            note: "The next Gradle build regenerates it."
        ),
        BuildArtifactRule(
            ".gradle",
            markers: ["build.gradle", "build.gradle.kts", "settings.gradle", "settings.gradle.kts"],
            label: "Gradle project cache",
            note: "The next Gradle build regenerates it."
        ),
        BuildArtifactRule(
            ".cxx",
            markers: ["build.gradle", "build.gradle.kts"],
            label: "Android NDK build output",
            note: "The next Gradle build regenerates it."
        ),
        BuildArtifactRule(
            "target",
            markers: ["pom.xml"],
            label: "Maven build output",
            note: "mvn package regenerates it."
        ),
        BuildArtifactRule(
            "build",
            markers: ["pubspec.yaml"],
            label: "Flutter build output",
            note: "flutter build regenerates it."
        ),
        BuildArtifactRule(
            ".dart_tool",
            markers: ["pubspec.yaml"],
            label: "Dart tool cache",
            note: "flutter pub get regenerates it."
        )
    ]

    private static let systemsRules: [BuildArtifactRule] = [
        BuildArtifactRule(
            "target",
            markers: ["Cargo.toml"],
            label: "Rust build output",
            note: "cargo build regenerates it."
        ),
        BuildArtifactRule(
            "build",
            markers: ["CMakeLists.txt", "meson.build", "Makefile"],
            label: "Build output",
            note: "Re-running the build regenerates it."
        ),
        BuildArtifactRule(
            "cmake-build-debug",
            markers: ["CMakeLists.txt"],
            label: "CMake build output",
            note: "Re-running the build regenerates it."
        ),
        BuildArtifactRule(
            "cmake-build-release",
            markers: ["CMakeLists.txt"],
            label: "CMake build output",
            note: "Re-running the build regenerates it."
        ),
        BuildArtifactRule(
            "obj",
            markers: ["*.csproj", "*.fsproj", "*.sln"],
            label: ".NET intermediate output",
            note: "dotnet build regenerates it."
        ),
        BuildArtifactRule(
            "bin",
            markers: ["*.csproj", "*.fsproj", "*.sln"],
            label: ".NET build output",
            note: "dotnet build regenerates it."
        ),
        BuildArtifactRule(
            "_build",
            markers: ["mix.exs", "dune-project"],
            label: "Build output",
            note: "The next build regenerates it."
        ),
        BuildArtifactRule(
            "deps",
            markers: ["mix.exs"],
            label: "Elixir dependencies",
            note: "mix deps.get puts them back."
        ),
        BuildArtifactRule(
            "elm-stuff",
            markers: ["elm.json"],
            label: "Elm dependencies",
            note: "The next build re-downloads them."
        ),
        BuildArtifactRule(
            ".terraform",
            markers: ["*.tf"],
            label: "Terraform providers",
            note: "terraform init re-downloads them."
        )
    ]

    private static let scriptingRules: [BuildArtifactRule] = [
        BuildArtifactRule(
            ".venv",
            contains: ["pyvenv.cfg"],
            label: "Python virtualenv",
            note: "Recreate with python -m venv and pip install -r requirements."
        ),
        BuildArtifactRule(
            "venv",
            contains: ["pyvenv.cfg"],
            label: "Python virtualenv",
            note: "Recreate with python -m venv and pip install -r requirements."
        ),
        BuildArtifactRule(
            "__pycache__",
            label: "Python bytecode cache",
            note: "Python rewrites it on the next import."
        ),
        BuildArtifactRule(
            ".pytest_cache",
            label: "pytest cache",
            note: "The next test run refills it."
        ),
        BuildArtifactRule(
            ".mypy_cache",
            label: "mypy cache",
            note: "The next type check refills it."
        ),
        BuildArtifactRule(
            ".ruff_cache",
            label: "Ruff cache",
            note: "The next lint run refills it."
        ),
        BuildArtifactRule(
            ".tox",
            markers: ["tox.ini"],
            label: "tox environments",
            note: "tox recreates them on the next run."
        ),
        BuildArtifactRule(
            "vendor",
            markers: ["composer.json"],
            label: "Composer dependencies",
            note: "composer install puts them back."
        ),
        BuildArtifactRule(
            "vendor",
            markers: ["Gemfile"],
            label: "Bundler dependencies",
            note: "bundle install puts them back."
        ),
        BuildArtifactRule(
            "vendor",
            markers: ["go.mod"],
            label: "Vendored Go modules",
            note: "go mod vendor puts them back."
        )
    ]

    static let knownDirectoryNames: Set<String> = Set(all.map { $0.directoryName.lowercased() })

    static func rule(forDirectoryNamed name: String) -> [BuildArtifactRule] {
        let lowered = name.lowercased()
        return all.filter { $0.directoryName.lowercased() == lowered }
    }
}
