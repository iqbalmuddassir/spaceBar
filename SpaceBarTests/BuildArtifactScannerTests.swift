import XCTest
@testable import SpaceBar

final class BuildArtifactScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("BuildArtifactScannerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        try super.tearDownWithError()
    }

    func testFindsArtifactBesideItsProjectMarker() throws {
        try makeProject("storefront", marker: "package.json", artifact: "node_modules")

        let found = BuildArtifactScanner.scan(roots: [root], minimumBytes: 0)

        XCTAssertEqual(found.count, 1)
        let artifact = try XCTUnwrap(found.first)
        XCTAssertEqual(artifact.projectName, "storefront")
        XCTAssertEqual(artifact.detailLabel, "Node dependencies")
        XCTAssertEqual(artifact.kind, .buildArtifact)
        XCTAssertEqual(artifact.displayName, "storefront / node_modules")
    }

    /// A hand-made `build` folder with no project around it is somebody's own work, not output.
    func testIgnoresArtifactNameWithoutAProjectMarker() throws {
        try makeProject("notes", marker: "readme.txt", artifact: "build")

        XCTAssertTrue(BuildArtifactScanner.scan(roots: [root], minimumBytes: 0).isEmpty)
    }

    /// Same folder name, different toolchain: the marker beside it decides what the row says.
    func testMarkerPicksBetweenRulesSharingADirectoryName() throws {
        try makeProject("engine", marker: "Cargo.toml", artifact: "target")
        try makeProject("service", marker: "pom.xml", artifact: "target")

        let labels = BuildArtifactScanner.scan(roots: [root], minimumBytes: 0)
            .reduce(into: [String: String]()) { $0[$1.projectName ?? ""] = $1.detailLabel }

        XCTAssertEqual(labels["engine"], "Rust build output")
        XCTAssertEqual(labels["service"], "Maven build output")
    }

    /// `venv` only counts when it actually holds a virtualenv.
    func testContentMarkerIsRequiredForVirtualenvs() throws {
        let project = try makeProject("forecast", marker: "requirements.txt", artifact: ".venv")
        XCTAssertTrue(BuildArtifactScanner.scan(roots: [root], minimumBytes: 0).isEmpty)

        try Data("home = /usr/bin".utf8).write(
            to: project.appendingPathComponent(".venv/pyvenv.cfg")
        )
        XCTAssertEqual(BuildArtifactScanner.scan(roots: [root], minimumBytes: 0).count, 1)
    }

    /// Nested `node_modules` are inside the folder that already got offered, so listing them
    /// separately would double-count the same bytes.
    func testDoesNotDescendIntoAMatchedArtifact() throws {
        let project = try makeProject("monorepo", marker: "package.json", artifact: "node_modules")
        let nested = project.appendingPathComponent("node_modules/left-pad", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: nested.appendingPathComponent("package.json"))
        try FileManager.default.createDirectory(
            at: nested.appendingPathComponent("node_modules", isDirectory: true),
            withIntermediateDirectories: true
        )

        let found = BuildArtifactScanner.scan(roots: [root], minimumBytes: 0)

        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.url.lastPathComponent, "node_modules")
    }

    func testSizeFloorHidesTrivialFolders() throws {
        try makeProject("tiny", marker: "package.json", artifact: "node_modules")

        XCTAssertTrue(BuildArtifactScanner.scan(roots: [root], minimumBytes: 10_000_000).isEmpty)
    }

    func testSearchRootsSkipSystemOwnedHomeFolders() {
        let names = Set(BuildArtifactScanner.searchRoots().map { $0.lastPathComponent.lowercased() })

        XCTAssertFalse(names.contains("library"))
        XCTAssertFalse(names.contains("pictures"))
    }

    @discardableResult
    private func makeProject(_ name: String, marker: String, artifact: String) throws -> URL {
        let project = root.appendingPathComponent(name, isDirectory: true)
        let artifactURL = project.appendingPathComponent(artifact, isDirectory: true)
        try FileManager.default.createDirectory(at: artifactURL, withIntermediateDirectories: true)
        try Data("marker".utf8).write(to: project.appendingPathComponent(marker))
        try Data("output".utf8).write(to: artifactURL.appendingPathComponent("artifact.bin"))
        return project
    }
}
